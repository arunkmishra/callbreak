import 'package:equatable/equatable.dart';
import '../data/models/playing_card.dart';

/// Base class for all GameBloc events.
abstract class GameEvent extends Equatable {
  const GameEvent();

  @override
  List<Object?> get props => [];
}

// ─── Matchmaking Events ──────────────────────────────────────────────────────

/// User taps "Create Game" on the Home screen.
class CreateRoomRequested extends GameEvent {
  final String playerName;
  final int totalRounds;
  const CreateRoomRequested(this.playerName, {this.totalRounds = 5});

  @override
  List<Object?> get props => [playerName, totalRounds];
}

/// User taps "Join Game" on the Home screen.
class JoinRoomRequested extends GameEvent {
  final String roomId;
  final String playerName;
  const JoinRoomRequested(this.roomId, this.playerName);

  @override
  List<Object?> get props => [roomId, playerName];
}

// ─── WebSocket Lifecycle ─────────────────────────────────────────────────────

/// Triggered internally when the WS connection is established.
class ConnectToRoom extends GameEvent {
  final String roomId;
  final String playerId;
  final String sessionToken;
  const ConnectToRoom(this.roomId, this.playerId, this.sessionToken);

  @override
  List<Object?> get props => [roomId, playerId, sessionToken];
}

/// Triggered every time the server broadcasts a STATE_UPDATE.
class ServerStateUpdated extends GameEvent {
  final dynamic gameState; // GameState — using dynamic to avoid circular import
  const ServerStateUpdated(this.gameState);

  @override
  List<Object?> get props => [gameState];
}

/// Triggered when the server sends an ERROR message.
class ServerErrorReceived extends GameEvent {
  final String reason;
  const ServerErrorReceived(this.reason);

  @override
  List<Object?> get props => [reason];
}

// ─── Game Action Events ──────────────────────────────────────────────────────

/// Host taps "Start Game" in the Lobby screen.
class StartGameRequested extends GameEvent {
  const StartGameRequested();
}

/// Player submits their bid during the BIDDING phase.
class PlaceBidAttempt extends GameEvent {
  final int bid;
  const PlaceBidAttempt(this.bid);

  @override
  List<Object?> get props => [bid];
}

/// Player taps a card in their hand during the PLAYING phase.
///
/// The BLoC MUST NOT update state locally — it sends PLAY_CARD to the server
/// and waits for the server STATE_UPDATE broadcast.
class PlayCardAttempt extends GameEvent {
  final PlayingCard card;
  const PlayCardAttempt(this.card);

  @override
  List<Object?> get props => [card];
}

/// Host requests to start the next round after ROUND_OVER.
class NextRoundRequested extends GameEvent {
  const NextRoundRequested();
}

/// User disconnects or navigates away.
class DisconnectRequested extends GameEvent {
  const DisconnectRequested();
}
