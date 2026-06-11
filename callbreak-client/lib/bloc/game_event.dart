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
  final int? minBid;
  final bool greedPenalty;
  final bool allowCustomTrump;
  const CreateRoomRequested(this.playerName, {this.totalRounds = 5, this.minBid = 1, this.greedPenalty = false, this.allowCustomTrump = false});

  @override
  List<Object?> get props => [playerName, totalRounds, minBid, greedPenalty, allowCustomTrump];
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

/// Fired when the app comes back to the foreground.
class AppResumed extends GameEvent {
  const AppResumed();
}

/// Fired when the reconnect engine changes status.
class ReconnectStatusChanged extends GameEvent {
  final bool isReconnecting;
  final bool hasFailed;
  const ReconnectStatusChanged({this.isReconnecting = false, this.hasFailed = false});

  @override
  List<Object?> get props => [isReconnecting, hasFailed];
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

/// Player submits a bid/pass during TRUMP_BIDDING phase.
class PlaceTrumpBidAttempt extends GameEvent {
  final int? bid;
  final String? suit;
  const PlaceTrumpBidAttempt(this.bid, this.suit);

  @override
  List<Object?> get props => [bid, suit];
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

/// Player taps "Rematch" on the game-over dialog.
///
/// Contains the finished [GameState] so the bloc knows the original room
/// settings (totalRounds, minBid, etc.) and the player roster (to detect
/// bot-only vs multiplayer games).
class RematchRequested extends GameEvent {
  final dynamic finishedGameState; // GameState — dynamic to avoid circular import
  const RematchRequested(this.finishedGameState);

  @override
  List<Object?> get props => [finishedGameState];
}

// ─── Emoticon Events ─────────────────────────────────────────────────────────

/// Player taps an emoticon in the picker — send to server.
class SendEmoticonRequested extends GameEvent {
  final String emoticon;
  const SendEmoticonRequested(this.emoticon);

  @override
  List<Object?> get props => [emoticon];
}

/// Server broadcast received — an emoticon was sent by a player in this room.
class EmoticonEventReceived extends GameEvent {
  final String playerId;
  final String emoticon;
  const EmoticonEventReceived(this.playerId, this.emoticon);

  @override
  List<Object?> get props => [playerId, emoticon];
}
