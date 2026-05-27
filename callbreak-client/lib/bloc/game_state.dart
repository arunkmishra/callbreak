import 'package:equatable/equatable.dart';
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
/// Holds the player ID for this session.
class GameLobby extends GameBlocState {
  final GameState gameState;
  final String myPlayerId;

  const GameLobby({required this.gameState, required this.myPlayerId});

  @override
  List<Object?> get props => [gameState, myPlayerId];
}

/// All players have bid; active trick-taking gameplay.
class GameBidding extends GameBlocState {
  final GameState gameState;
  final String myPlayerId;

  const GameBidding({required this.gameState, required this.myPlayerId});

  @override
  List<Object?> get props => [gameState, myPlayerId];
}

/// Active trick-taking gameplay phase.
class GameActive extends GameBlocState {
  final GameState gameState;
  final String myPlayerId;

  /// Whether the local player has just played a card and is awaiting confirmation.
  final bool awaitingServer;

  const GameActive({
    required this.gameState,
    required this.myPlayerId,
    this.awaitingServer = false,
  });

  @override
  List<Object?> get props => [gameState, myPlayerId, awaitingServer];
}

/// Round is over; showing scores. Host can start the next round.
class GameRoundOver extends GameBlocState {
  final GameState gameState;
  final String myPlayerId;
  final bool isGameOver;

  const GameRoundOver({
    required this.gameState,
    required this.myPlayerId,
    required this.isGameOver,
  });

  @override
  List<Object?> get props => [gameState, myPlayerId, isGameOver];
}
