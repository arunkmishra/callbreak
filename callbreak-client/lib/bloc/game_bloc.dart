import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/models/game_state.dart';
import '../data/repositories/api_repository.dart';
import '../data/repositories/socket_repository.dart';
import 'game_event.dart';
import 'game_state.dart';

/// The central BLoC for the Callbreak game.
///
/// Key architectural rule (from spec):
///   The BLoC MUST NEVER mutate local state when a card is played.
///   It sends the action to the server and waits for the SERVER to broadcast
///   the new state via WebSocket [ServerStateUpdated].
///
/// State machine:
///   GameInitial
///     ↓ CreateRoomRequested / JoinRoomRequested
///   GameLoading
///     ↓ ConnectToRoom (after REST success)
///   GameLobby
///     ↓ ServerStateUpdated (phase = BIDDING)
///   GameBidding
///     ↓ ServerStateUpdated (phase = PLAYING)
///   GameActive
///     ↓ ServerStateUpdated (phase = ROUND_OVER)
///   GameRoundOver
///     ↓ NextRoundRequested → ServerStateUpdated (phase = BIDDING)
///   GameBidding ...
class GameBloc extends Bloc<GameEvent, GameBlocState> {
  final ApiRepository _apiRepository;
  final SocketRepository _socketRepository;

  String? _myPlayerId;
  StreamSubscription<GameState>? _socketSubscription;

  GameBloc({
    required ApiRepository apiRepository,
    required SocketRepository socketRepository,
  })  : _apiRepository = apiRepository,
        _socketRepository = socketRepository,
        super(const GameInitial()) {
    on<CreateRoomRequested>(_onCreateRoom);
    on<JoinRoomRequested>(_onJoinRoom);
    on<ConnectToRoom>(_onConnectToRoom);
    on<ServerStateUpdated>(_onServerStateUpdated);
    on<ServerErrorReceived>(_onServerError);
    on<StartGameRequested>(_onStartGame);
    on<PlaceBidAttempt>(_onPlaceBid);
    on<PlaceTrumpBidAttempt>(_onPlaceTrumpBid);
    on<PlayCardAttempt>(_onPlayCard);
    on<NextRoundRequested>(_onNextRound);
    on<DisconnectRequested>(_onDisconnect);
  }

  // ─── Matchmaking ──────────────────────────────────────────────────────────

  Future<void> _onCreateRoom(
    CreateRoomRequested event,
    Emitter<GameBlocState> emit,
  ) async {
    emit(const GameLoading());
    try {
      final result = await _apiRepository.createRoom(
        event.playerName,
        totalRounds: event.totalRounds,
        minBid: event.minBid,
        greedPenalty: event.greedPenalty,
        allowCustomTrump: event.allowCustomTrump,
      );
      _myPlayerId = result.playerId;
      add(ConnectToRoom(result.roomId, result.playerId, result.sessionToken));
    } on ApiException catch (e) {
      emit(GameError(e.message));
    } catch (e) {
      emit(GameError('Failed to create room: $e'));
    }
  }

  Future<void> _onJoinRoom(
    JoinRoomRequested event,
    Emitter<GameBlocState> emit,
  ) async {
    emit(const GameLoading());
    try {
      final result = await _apiRepository.joinRoom(event.roomId, event.playerName);
      _myPlayerId = result.playerId;
      add(ConnectToRoom(result.roomId, result.playerId, result.sessionToken));
    } on ApiException catch (e) {
      emit(GameError(e.message));
    } catch (e) {
      emit(GameError('Failed to join room: $e'));
    }
  }

  // ─── WebSocket Connection ─────────────────────────────────────────────────

  Future<void> _onConnectToRoom(
    ConnectToRoom event,
    Emitter<GameBlocState> emit,
  ) async {
    final stream = _socketRepository.connect(event.roomId, event.playerId, event.sessionToken);

    await _socketSubscription?.cancel();
    _socketSubscription = stream.listen(
      (gameState) => add(ServerStateUpdated(gameState)),
      onError: (Object error) {
        if (error is ServerError) {
          add(ServerErrorReceived(error.reason));
        } else {
          add(ServerErrorReceived('Connection error: $error'));
        }
      },
    );
  }

  // ─── Server State Updates ─────────────────────────────────────────────────

  void _onServerStateUpdated(
    ServerStateUpdated event,
    Emitter<GameBlocState> emit,
  ) {
    final gameState = event.gameState as GameState;
    final playerId = _myPlayerId ?? '';

    switch (gameState.phase) {
      case GamePhase.lobby:
        emit(GameLobby(gameState: gameState, myPlayerId: playerId));
      case GamePhase.dealingPhase1:
      case GamePhase.trumpBidding:
      case GamePhase.dealingPhase2:
      case GamePhase.regularBidding:
        emit(GameBidding(gameState: gameState, myPlayerId: playerId));
      case GamePhase.bidding: // legacy fallback
        emit(GameBidding(gameState: gameState, myPlayerId: playerId));
      case GamePhase.playing:
        emit(GameActive(gameState: gameState, myPlayerId: playerId));
      case GamePhase.roundOver:
        emit(GameRoundOver(
          gameState: gameState,
          myPlayerId: playerId,
          isGameOver: false,
        ));
      case GamePhase.gameOver:
        emit(GameRoundOver(
          gameState: gameState,
          myPlayerId: playerId,
          isGameOver: true,
        ));
    }
  }

  void _onServerError(
    ServerErrorReceived event,
    Emitter<GameBlocState> emit,
  ) {
    print('🚨 ServerErrorReceived: ${event.reason}');
    // Preserve the current game state but surface the error.
    // The UI shows a snackbar/toast rather than replacing the screen.
    emit(GameError(event.reason));
  }

  // ─── Game Actions ─────────────────────────────────────────────────────────

  void _onStartGame(StartGameRequested event, Emitter<GameBlocState> emit) {
    _socketRepository.sendAction('START_GAME');
  }

  void _onPlaceBid(PlaceBidAttempt event, Emitter<GameBlocState> emit) {
    _socketRepository.sendAction('PLACE_BID', {'bid': event.bid});
  }

  void _onPlaceTrumpBid(PlaceTrumpBidAttempt event, Emitter<GameBlocState> emit) {
    _socketRepository.sendAction('PLACE_TRUMP_BID', {'bid': event.bid, 'suit': event.suit});
  }

  void _onPlayCard(PlayCardAttempt event, Emitter<GameBlocState> emit) {
    // Mark as awaiting so the UI can show a spinner/disabled state.
    if (state is GameActive) {
      emit((state as GameActive).copyWith(awaitingServer: true));
    }
    _socketRepository.sendAction('PLAY_CARD', {
      'suit': event.card.suit,
      'rank': event.card.rank,
    });
    // State will be restored by the next ServerStateUpdated event.
  }

  void _onNextRound(NextRoundRequested event, Emitter<GameBlocState> emit) {
    _socketRepository.sendAction('START_GAME'); // reuses start flow for next round
  }

  void _onDisconnect(DisconnectRequested event, Emitter<GameBlocState> emit) {
    _cleanUp();
    emit(const GameInitial());
  }

  // ─── Cleanup ──────────────────────────────────────────────────────────────

  void _cleanUp() {
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socketRepository.disconnect();
    _myPlayerId = null;
  }

  @override
  Future<void> close() {
    _cleanUp();
    return super.close();
  }
}

// ─── copyWith helper ─────────────────────────────────────────────────────────

extension GameActiveX on GameActive {
  GameActive copyWith({
    GameState? gameState,
    String? myPlayerId,
    bool? awaitingServer,
  }) =>
      GameActive(
        gameState: gameState ?? this.gameState,
        myPlayerId: myPlayerId ?? this.myPlayerId,
        awaitingServer: awaitingServer ?? this.awaitingServer,
      );
}
