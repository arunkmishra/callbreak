import 'package:equatable/equatable.dart';
import '../data/models/emoticon_event.dart';
import '../data/models/game_state.dart';

/// Base class for all GameBloc states.
abstract class GameBlocState extends Equatable {
  const GameBlocState();

  @override
  List<Object?> get props => [];
}

// ─── Pre-connection ──────────────────────────────────────────────────────────

/// Initial state — Home screen is shown.
class GameInitial extends GameBlocState {
  const GameInitial();
}

/// Loading state while creating/joining a room or connecting to WS.
class GameLoading extends GameBlocState {
  const GameLoading();
}

/// An error occurred (network, server, or validation).
class GameError extends GameBlocState {
  final String message;
  const GameError(this.message);

  @override
  List<Object?> get props => [message];
}

// ─── Connected States ────────────────────────────────────────────────────────

/// Successfully connected; waiting in the lobby for other players.
class GameLobby extends GameBlocState {
  final GameState gameState;
  final String myPlayerId;
  final bool isReconnecting;

  const GameLobby({
    required this.gameState,
    required this.myPlayerId,
    this.isReconnecting = false,
  });

  GameLobby copyWith({GameState? gameState, String? myPlayerId, bool? isReconnecting}) =>
      GameLobby(
        gameState: gameState ?? this.gameState,
        myPlayerId: myPlayerId ?? this.myPlayerId,
        isReconnecting: isReconnecting ?? this.isReconnecting,
      );

  @override
  List<Object?> get props => [gameState, myPlayerId, isReconnecting];
}

/// Bidding phase (trump bidding or regular bidding).
class GameBidding extends GameBlocState {
  final GameState gameState;
  final String myPlayerId;
  final bool isReconnecting;
  /// Non-null briefly when an emoticon broadcast arrives; the BLoC clears it
  /// after a short delay so the overlay animation can play once.
  final EmoticonEvent? pendingEmoticon;

  const GameBidding({
    required this.gameState,
    required this.myPlayerId,
    this.isReconnecting = false,
    this.pendingEmoticon,
  });

  GameBidding copyWith({
    GameState? gameState,
    String? myPlayerId,
    bool? isReconnecting,
    EmoticonEvent? pendingEmoticon,
    bool clearEmoticon = false,
  }) =>
      GameBidding(
        gameState: gameState ?? this.gameState,
        myPlayerId: myPlayerId ?? this.myPlayerId,
        isReconnecting: isReconnecting ?? this.isReconnecting,
        pendingEmoticon: clearEmoticon ? null : (pendingEmoticon ?? this.pendingEmoticon),
      );

  @override
  List<Object?> get props => [gameState, myPlayerId, isReconnecting, pendingEmoticon];
}

/// Active trick-taking gameplay phase.
class GameActive extends GameBlocState {
  final GameState gameState;
  final String myPlayerId;

  /// Whether the local player just played a card and is awaiting confirmation.
  final bool awaitingServer;
  final bool isReconnecting;
  /// Non-null briefly when an emoticon broadcast arrives; cleared by BLoC after delay.
  final EmoticonEvent? pendingEmoticon;

  const GameActive({
    required this.gameState,
    required this.myPlayerId,
    this.awaitingServer = false,
    this.isReconnecting = false,
    this.pendingEmoticon,
  });

  GameActive copyWith({
    GameState? gameState,
    String? myPlayerId,
    bool? awaitingServer,
    bool? isReconnecting,
    EmoticonEvent? pendingEmoticon,
    bool clearEmoticon = false,
  }) =>
      GameActive(
        gameState: gameState ?? this.gameState,
        myPlayerId: myPlayerId ?? this.myPlayerId,
        awaitingServer: awaitingServer ?? this.awaitingServer,
        isReconnecting: isReconnecting ?? this.isReconnecting,
        pendingEmoticon: clearEmoticon ? null : (pendingEmoticon ?? this.pendingEmoticon),
      );

  @override
  List<Object?> get props => [gameState, myPlayerId, awaitingServer, isReconnecting, pendingEmoticon];
}

/// Round is over; showing scores.
class GameRoundOver extends GameBlocState {
  final GameState gameState;
  final String myPlayerId;
  final bool isGameOver;
  final bool isReconnecting;

  const GameRoundOver({
    required this.gameState,
    required this.myPlayerId,
    required this.isGameOver,
    this.isReconnecting = false,
  });

  GameRoundOver copyWith({
    GameState? gameState,
    String? myPlayerId,
    bool? isGameOver,
    bool? isReconnecting,
  }) =>
      GameRoundOver(
        gameState: gameState ?? this.gameState,
        myPlayerId: myPlayerId ?? this.myPlayerId,
        isGameOver: isGameOver ?? this.isGameOver,
        isReconnecting: isReconnecting ?? this.isReconnecting,
      );

  @override
  List<Object?> get props => [gameState, myPlayerId, isGameOver, isReconnecting];
}

/// Alias so screens can check `state is GameOver`.
typedef GameOver = GameRoundOver;
