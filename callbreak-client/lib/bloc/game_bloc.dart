import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/audio_service.dart';
import '../core/session_storage.dart';
import '../core/stats_prefs.dart';
import '../data/models/emoticon_event.dart';
import '../data/models/game_state.dart';
import '../data/repositories/api_repository.dart';
import '../data/repositories/socket_repository.dart';
import '../data/services/heartbeat_service.dart';
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
  String? _myPlayerName;
  StreamSubscription<GameState>? _socketSubscription;
  StreamSubscription<ReconnectStatus>? _reconnectSubscription;
  StreamSubscription<EmoticonEvent>? _emoticonSubscription;

  /// Supabase Realtime channel opened at game-over to coordinate rematches.
  RealtimeChannel? _rematchChannel;

  /// True when the current player clicked Rematch (or received a rematch invite)
  /// so we ignore any subsequent duplicate broadcasts.
  bool _isJoiningRematch = false;

  /// True when a bot-game rematch is pending — makes the bloc auto-send
  /// START_GAME as soon as the server emits the lobby phase for the new room.
  bool _pendingBotRematch = false;

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
    on<RematchRequested>(_onRematch);
    on<SendEmoticonRequested>(_onSendEmoticon);
    on<EmoticonEventReceived>(_onEmoticonReceived);
    on<ClearEmoticonRequested>(_onClearEmoticonRequested);

    WidgetsBinding.instance.addObserver(this);

    // On startup, check for a saved session and silently reconnect if found
    _tryRestoreSession();
  }

  // ─── App Lifecycle ────────────────────────────────────────────────────────

  @override
  void onChange(Change<GameBlocState> change) {
    super.onChange(change);
    final nextState = change.nextState;
    if (nextState is GameInitial || nextState is GameError) {
      HeartbeatService.currentStatus = 'available';
    } else {
      HeartbeatService.currentStatus = 'playing';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      add(const AppResumed());
    }
  }

  void _onAppResumed(AppResumed event, Emitter<GameBlocState> emit) {
    if (_socketRepository.isConnected) return;

    // Check if we're already trying to reconnect to avoid spamming connect()
    final currentState = state;
    bool isReconnecting = false;
    if (currentState is GameActive) isReconnecting = currentState.isReconnecting;
    if (currentState is GameLobby) isReconnecting = currentState.isReconnecting;
    if (currentState is GameBidding) isReconnecting = currentState.isReconnecting;
    if (currentState is GameRoundOver) isReconnecting = currentState.isReconnecting;

    if (isReconnecting) return;

    _sessionStorage.load().then((session) {
      if (session != null) {
        _myPlayerId = session.playerId; // ensure memory cache is restored
        add(ConnectToRoom(session.roomId, session.playerId, session.sessionToken));
      }
    });
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
    // Proactively clear any stale session/connection before starting fresh
    _cleanUp();
    _sessionStorage.clear();
    _myPlayerName = event.playerName;

    emit(const GameLoading());
    try {
      final supabaseId = Supabase.instance.client.auth.currentUser?.id;
      final result = await _apiRepository.createRoom(
        event.playerName,
        supabaseId,
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
    // Proactively clear any stale session/connection before joining a new one
    _cleanUp();
    _sessionStorage.clear();
    _myPlayerName = event.playerName;

    emit(const GameLoading());
    try {
      final supabaseId = Supabase.instance.client.auth.currentUser?.id;
      final result = await _apiRepository.joinRoom(event.roomId, event.playerName, supabaseId);
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

    // Listen to emoticon broadcasts
    await _emoticonSubscription?.cancel();
    _emoticonSubscription = _socketRepository.emoticonStream.listen((event) {
      add(EmoticonEventReceived(event.playerId, event.emoticon));
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
      // All retries exhausted — do NOT clear session! 
      // If the user's internet is just down for a long time, we want them to 
      // be able to restart the app and use their saved sessionToken to reclaim their seat.
      _cleanUp();
      emit(const GameError('Connection lost. Please check your internet and restart the app to rejoin.'));
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

    final currentState = state;
    bool currentIsReconnecting = false;
    if (currentState is GameActive) {
      currentIsReconnecting = currentState.isReconnecting;
    } else if (currentState is GameBidding) {
      currentIsReconnecting = currentState.isReconnecting;
    } else if (currentState is GameLobby) {
      currentIsReconnecting = currentState.isReconnecting;
    } else if (currentState is GameRoundOver) {
      currentIsReconnecting = currentState.isReconnecting;
    }

    final isMyTurnNow = gameState.isMyTurn(playerId);
    bool turnChanged = false;

    if (currentState is GameBidding) {
      turnChanged = currentState.gameState.currentTurn != gameState.currentTurn;
    } else if (currentState is GameActive) {
      turnChanged = currentState.gameState.currentTurn != gameState.currentTurn;
      // If it remained my turn but the trick advanced or cleared, it's a new turn for me
      if (!turnChanged && isMyTurnNow) {
        final oldTrick = currentState.gameState.currentTrick;
        final newTrick = gameState.currentTrick;
        if (oldTrick.cards.length != newTrick.cards.length) {
          turnChanged = true;
        }
      }
    }

    if (turnChanged && isMyTurnNow && gameState.phase != GamePhase.lobby && gameState.phase != GamePhase.gameOver && gameState.phase != GamePhase.roundOver) {
      AudioService.playTurnAlert();
    }

    switch (gameState.phase) {
      case GamePhase.lobby:
        // Bot-rematch: skip the lobby flash and auto-start immediately
        if (_pendingBotRematch) {
          _pendingBotRematch = false;
          _socketRepository.sendAction('START_GAME');
          return;
        }
        emit(GameLobby(gameState: gameState, myPlayerId: playerId, isReconnecting: currentIsReconnecting));
      case GamePhase.dealingPhase1:
      case GamePhase.trumpBidding:
      case GamePhase.dealingPhase2:
      case GamePhase.regularBidding:
      case GamePhase.bidding:
        emit(GameBidding(gameState: gameState, myPlayerId: playerId, isReconnecting: currentIsReconnecting));
      case GamePhase.playing:
        emit(GameActive(gameState: gameState, myPlayerId: playerId, isReconnecting: currentIsReconnecting));
      case GamePhase.roundOver:
        emit(GameRoundOver(
          gameState: gameState,
          myPlayerId: playerId,
          isGameOver: false,
          isReconnecting: currentIsReconnecting,
        ));
      case GamePhase.gameOver:
        // Clear session — game is over, no need to reconnect
        _sessionStorage.clear();

        try {
          final me = gameState.players.firstWhere((p) => p.id == playerId);
          final bool won = me.rank == 1;
          StatsPrefs.recordGame(won: won, points: me.cumulativeScore);
        } catch (_) {}

        // ── Open rematch coordination channel ────────────────────────────
        // All players subscribe to rematch_{roomId}. Whoever clicks "Rematch"
        // first creates a new room and broadcasts {newRoomId} here. Others
        // auto-join that room without needing to do anything manually.
        _isJoiningRematch = false;
        _rematchChannel?.unsubscribe();
        _rematchChannel = Supabase.instance.client
            .channel('rematch_${gameState.roomId}')
          ..onBroadcast(
            event: 'rematch',
            callback: (payload) {
              if (_isJoiningRematch) return; // already handled (we were the initiator)
              _isJoiningRematch = true;
              final newRoomId = payload['newRoomId'] as String?;
              if (newRoomId == null) return;
              // Auto-join the new room using our saved player name
              add(JoinRoomRequested(newRoomId, _myPlayerName ?? 'Player'));
            },
          )
          ..subscribe();

        emit(GameRoundOver(
          gameState: gameState,
          myPlayerId: playerId,
          isGameOver: true,
          isReconnecting: currentIsReconnecting,
        ));
    }
  }

  void _onServerError(
    ServerErrorReceived event,
    Emitter<GameBlocState> emit,
  ) {
    print('🚨 ServerErrorReceived: ${event.reason}');
    
    // If the error indicates the room is dead/missing or session is invalid, clear the session
    final reasonLower = event.reason.toLowerCase();
    if (reasonLower.contains('not found') || 
        reasonLower.contains('invalid') || 
        reasonLower.contains('expired')) {
      _sessionStorage.clear();
      _cleanUp();
    }
    
    // Ignore turn sync race conditions ("It is not X's turn") from the backend
    if (event.reason.startsWith('It is not ') && event.reason.contains('turn')) {
      print('ℹ️ Ignoring turn sync error: ${event.reason}');
      
      final currentState = state;
      // We still need to unblock the UI if it was awaiting the server
      if (currentState is GameActive) {
        emit(currentState.copyWith(awaitingServer: false));
      }
      return; // Skip emitting GameError to avoid annoying red snackbars
    }

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

  Future<void> _onDisconnect(DisconnectRequested event, Emitter<GameBlocState> emit) async {
    _socketRepository.sendAction('LEAVE_ROOM');
    await _sessionStorage.clear(); // Intentional — clear saved session
    _cleanUp();
    emit(const GameInitial());
  }

  // ─── Rematch ──────────────────────────────────────────────────────────────

  // ─── Emoticons ────────────────────────────────────────────────────────────

  void _onSendEmoticon(SendEmoticonRequested event, Emitter<GameBlocState> emit) {
    _socketRepository.sendAction('SEND_EMOTICON', {'emoticon': event.emoticon});
  }

  void _onEmoticonReceived(EmoticonEventReceived event, Emitter<GameBlocState> emit) {
    final emoticonEvent = EmoticonEvent(playerId: event.playerId, emoticon: event.emoticon);
    final current = state;
    if (current is GameActive) {
      emit(current.copyWith(pendingEmoticon: emoticonEvent));
    } else if (current is GameBidding) {
      emit(current.copyWith(pendingEmoticon: emoticonEvent));
    }
    
    // The overlay widget handles its own display duration; the BLoC
    // clears the pending event after a brief delay to avoid Equatable
    // blocking future identical emotes from the same player.
    // Instead of calling emit in a delayed future, we add a new event.
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (!isClosed) {
        add(ClearEmoticonRequested(event.playerId));
      }
    });
  }

  void _onClearEmoticonRequested(ClearEmoticonRequested event, Emitter<GameBlocState> emit) {
    final s = state;
    if (s is GameActive && s.pendingEmoticon?.playerId == event.playerId) {
      emit(s.copyWith(clearEmoticon: true));
    } else if (s is GameBidding && s.pendingEmoticon?.playerId == event.playerId) {
      emit(s.copyWith(clearEmoticon: true));
    }
  }

  Future<void> _onRematch(
    RematchRequested event,
    Emitter<GameBlocState> emit,
  ) async {
    if (_isJoiningRematch) return; // already joining — ignore double-tap
    _isJoiningRematch = true;

    final gs = event.finishedGameState as GameState;
    // A "bot game" is one where the local player is the *only* human.
    // Multiplayer games with bot fill-ins (e.g. 2 humans + 2 bots) must use
    // the broadcast/lobby flow so both real players end up in the same room.
    final humanPlayers = gs.players.where((p) => !p.isBot).toList();
    final isBotGame = humanPlayers.length <= 1;
    final myPlayer = gs.players.firstWhere(
      (p) => p.id == _myPlayerId,
      orElse: () => gs.players.first,
    );

    // Tear down the old connection cleanly (WS already dead after game over,
    // but cancel subscriptions to prevent stale events).
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _reconnectSubscription?.cancel();
    _reconnectSubscription = null;
    _socketRepository.disconnect();
    // Keep _myPlayerId until we set the new one below.

    emit(const GameLoading());

    try {
      final supabaseId = Supabase.instance.client.auth.currentUser?.id;
      final result = await _apiRepository.createRoom(
        myPlayer.name,
        supabaseId,
        totalRounds: gs.totalRounds,
        minBid: gs.minBid,
        greedPenalty: gs.greedPenalty,
        allowCustomTrump: gs.allowCustomTrump,
      );

      _myPlayerId = result.playerId;
      _myPlayerName = myPlayer.name;
      await _sessionStorage.save(
        roomId: result.roomId,
        playerId: result.playerId,
        sessionToken: result.sessionToken,
      );

      if (isBotGame) {
        // Signal _onServerStateUpdated to skip the lobby state and start immediately.
        _pendingBotRematch = true;
      } else {
        // Broadcast the new room ID to all other players still subscribed to
        // the rematch channel. They will auto-join via _onServerStateUpdated.
        try {
          await _rematchChannel?.sendBroadcastMessage(
            event: 'rematch',
            payload: {'newRoomId': result.roomId},
          );
        } catch (_) { /* broadcast best-effort */ }
      }

      // Now close and null out the rematch channel — we no longer need it
      _rematchChannel?.unsubscribe();
      _rematchChannel = null;

      add(ConnectToRoom(result.roomId, result.playerId, result.sessionToken));
      _isJoiningRematch = false;
    } on ApiException catch (e) {
      _isJoiningRematch = false;
      emit(GameError(e.message));
    } catch (e) {
      _isJoiningRematch = false;
      emit(GameError('Failed to start rematch: $e'));
    }
  }

  // ─── Cleanup ──────────────────────────────────────────────────────────────

  void _cleanUp() {
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _reconnectSubscription?.cancel();
    _reconnectSubscription = null;
    _emoticonSubscription?.cancel();
    _emoticonSubscription = null;
    _socketRepository.disconnect();
    _rematchChannel?.unsubscribe();
    _rematchChannel = null;
    _isJoiningRematch = false;
    _pendingBotRematch = false;
    _myPlayerId = null;
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanUp();
    return super.close();
  }
}
