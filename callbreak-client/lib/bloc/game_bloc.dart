import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/models/game_state.dart';
import '../data/repositories/api_repository.dart';
import '../data/repositories/socket_repository.dart';
import '../core/session_storage.dart';
import 'game_event.dart';
import 'game_state.dart';

/// The central BLoC for the Callbreak game.
///
/// Handles WebSocket lifecycle with auto-reconnect, app lifecycle awareness,
/// and persistent session storage so players can return after process kills.
class GameBloc extends Bloc<GameEvent, GameBlocState> with WidgetsBindingObserver {
  final ApiRepository _apiRepository;
  final SocketRepository _socketRepository;
  final SessionStorage _sessionStorage;

  String? _myPlayerId;
  StreamSubscription<GameState>? _socketSubscription;
  StreamSubscription<ReconnectStatus>? _reconnectSubscription;

  GameBloc({
    required ApiRepository apiRepository,
    required SocketRepository socketRepository,
    required SessionStorage sessionStorage,
  })  : _apiRepository = apiRepository,
        _socketRepository = socketRepository,
        _sessionStorage = sessionStorage,
        super(const GameInitial()) {
    on<CreateRoomRequested>(_onCreateRoom);
    on<JoinRoomRequested>(_onJoinRoom);
    on<ConnectToRoom>(_onConnectToRoom);
    on<AppResumed>(_onAppResumed);
    on<ReconnectStatusChanged>(_onReconnectStatusChanged);
    on<ServerStateUpdated>(_onServerStateUpdated);
    on<ServerErrorReceived>(_onServerError);
    on<StartGameRequested>(_onStartGame);
    on<PlaceBidAttempt>(_onPlaceBid);
    on<PlaceTrumpBidAttempt>(_onPlaceTrumpBid);
    on<PlayCardAttempt>(_onPlayCard);
    on<NextRoundRequested>(_onNextRound);
    on<DisconnectRequested>(_onDisconnect);

    WidgetsBinding.instance.addObserver(this);

    // On startup, check for a saved session and silently reconnect if found
    _tryRestoreSession();
  }

  // ─── App Lifecycle ────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      add(const AppResumed());
    }
  }

  void _onAppResumed(AppResumed event, Emitter<GameBlocState> emit) {
    // If we have a session but no live socket, reconnect silently
    if (!_socketRepository.isConnected &&
        _myPlayerId != null &&
        (this.state is GameActive ||
            this.state is GameBidding ||
            this.state is GameLobby ||
            this.state is GameRoundOver)) {
      _sessionStorage.load().then((session) {
        if (session != null) {
          add(ConnectToRoom(session.roomId, session.playerId, session.sessionToken));
        }
      });
    }
  }

  // ─── Session Restore ──────────────────────────────────────────────────────

  Future<void> _tryRestoreSession() async {
    final session = await _sessionStorage.load();
    if (session == null) return;

    _myPlayerId = session.playerId;
    add(ConnectToRoom(session.roomId, session.playerId, session.sessionToken));
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
      await _sessionStorage.save(
        roomId: result.roomId,
        playerId: result.playerId,
        sessionToken: result.sessionToken,
      );
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
      await _sessionStorage.save(
        roomId: result.roomId,
        playerId: result.playerId,
        sessionToken: result.sessionToken,
      );
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
    final stream =
        _socketRepository.connect(event.roomId, event.playerId, event.sessionToken);

    // Listen to reconnect status changes
    await _reconnectSubscription?.cancel();
    _reconnectSubscription =
        _socketRepository.reconnectStatusStream.listen((status) {
      add(ReconnectStatusChanged(
        isReconnecting: status == ReconnectStatus.reconnecting,
        hasFailed: status == ReconnectStatus.failed,
      ));
    });

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

  // ─── Reconnect Status ─────────────────────────────────────────────────────

  void _onReconnectStatusChanged(
    ReconnectStatusChanged event,
    Emitter<GameBlocState> emit,
  ) {
    if (event.hasFailed) {
      // All retries exhausted — clear session and send user home
      _sessionStorage.clear();
      emit(const GameError('Connection lost. Please rejoin the room.'));
      return;
    }

    // Propagate isReconnecting flag into current state for UI banner
    final current = state;
    if (current is GameActive) {
      emit(current.copyWith(isReconnecting: event.isReconnecting));
    } else if (current is GameBidding) {
      emit(current.copyWith(isReconnecting: event.isReconnecting));
    } else if (current is GameLobby) {
      emit(current.copyWith(isReconnecting: event.isReconnecting));
    } else if (current is GameRoundOver) {
      emit(current.copyWith(isReconnecting: event.isReconnecting));
    }
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
      case GamePhase.bidding:
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
        // Clear session — game is over, no need to reconnect
        _sessionStorage.clear();
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
    final currentState = state;
    emit(GameError(event.reason));

    // Restore the previous in-game state so the user isn't stuck on a loading screen
    if (currentState is GameActive) {
      emit(currentState.copyWith(awaitingServer: false));
    } else if (currentState is GameBidding) {
      emit(currentState);
    } else if (currentState is GameLobby) {
      emit(currentState);
    }
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
    if (state is GameActive) {
      emit((state as GameActive).copyWith(awaitingServer: true));
    }
    _socketRepository.sendAction('PLAY_CARD', {
      'suit': event.card.suit,
      'rank': event.card.rank,
    });
  }

  void _onNextRound(NextRoundRequested event, Emitter<GameBlocState> emit) {
    _socketRepository.sendAction('START_GAME');
  }

  void _onDisconnect(DisconnectRequested event, Emitter<GameBlocState> emit) {
    _sessionStorage.clear(); // Intentional — clear saved session
    _cleanUp();
    emit(const GameInitial());
  }

  // ─── Cleanup ──────────────────────────────────────────────────────────────

  void _cleanUp() {
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _reconnectSubscription?.cancel();
    _reconnectSubscription = null;
    _socketRepository.disconnect();
    _myPlayerId = null;
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanUp();
    return super.close();
  }
}
