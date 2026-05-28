import 'package:equatable/equatable.dart';
import 'player.dart';
import 'playing_card.dart';

/// All possible game phases, mirroring the server-side [GamePhase] enum.
enum GamePhase { lobby, dealingPhase1, trumpBidding, dealingPhase2, regularBidding, playing, roundOver, gameOver, bidding }

GamePhase gamePhaseFromString(String value) {
  switch (value.toUpperCase()) {
    case 'LOBBY':
      return GamePhase.lobby;
    case 'DEALING_PHASE_1':
      return GamePhase.dealingPhase1;
    case 'TRUMP_BIDDING':
      return GamePhase.trumpBidding;
    case 'DEALING_PHASE_2':
      return GamePhase.dealingPhase2;
    case 'REGULAR_BIDDING':
      return GamePhase.regularBidding;
    case 'BIDDING': // fallback
      return GamePhase.bidding;
    case 'PLAYING':
      return GamePhase.playing;
    case 'ROUND_OVER':
      return GamePhase.roundOver;
    case 'GAME_OVER':
      return GamePhase.gameOver;
    default:
      return GamePhase.lobby;
  }
}

class TrumpBidState extends Equatable {
  final int highestBid;
  final String? highestBidderId;
  final String? proposedSuit;
  final List<String> playersPassed;

  const TrumpBidState({
    this.highestBid = 0,
    this.highestBidderId,
    this.proposedSuit,
    this.playersPassed = const [],
  });

  factory TrumpBidState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TrumpBidState();
    return TrumpBidState(
      highestBid: json['highestBid'] as int? ?? 0,
      highestBidderId: json['highestBidderId'] as String?,
      proposedSuit: json['proposedSuit'] as String?,
      playersPassed: (json['playersPassed'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
    );
  }

  @override
  List<Object?> get props => [highestBid, highestBidderId, proposedSuit, playersPassed];
}

/// A single card played to the current trick, with the player who played it.
class TrickCard extends Equatable {
  final String playerId;
  final PlayingCard card;

  const TrickCard({required this.playerId, required this.card});

  factory TrickCard.fromJson(Map<String, dynamic> json) => TrickCard(
        playerId: json['playerId'] as String,
        card: PlayingCard.fromJson(json['card'] as Map<String, dynamic>),
      );

  @override
  List<Object?> get props => [playerId, card];
}

/// The current trick in progress.
class CurrentTrick extends Equatable {
  final String? ledSuit;
  final List<TrickCard> cards;

  const CurrentTrick({this.ledSuit, this.cards = const []});

  factory CurrentTrick.fromJson(Map<String, dynamic> json) {
    final rawSuit = json['ledSuit'] as String?;
    return CurrentTrick(
      ledSuit: rawSuit != null ? _normalizeSuit(rawSuit) : null,
      cards: (json['cards'] as List<dynamic>? ?? [])
          .map((c) => TrickCard.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  static String _normalizeSuit(String s) {
    if (s.toUpperCase() == 'SPADE') return 'Spade';
    if (s.toUpperCase() == 'HEART') return 'Heart';
    if (s.toUpperCase() == 'DIAMOND') return 'Diamond';
    if (s.toUpperCase() == 'CLUB') return 'Club';
    return s;
  }

  bool get isEmpty => cards.isEmpty;

  @override
  List<Object?> get props => [ledSuit, cards];
}

/// The full game state received from the server via WebSocket STATE_UPDATE.
///
/// [myHand] is populated only for the receiving player.
/// All other players' hands are represented via [Player.cardCount].
class GameState extends Equatable {
  final String roomId;
  final GamePhase phase;
  final List<Player> players;
  final List<PlayingCard> myHand;
  final String? currentTurn;
  final CurrentTrick currentTrick;

  /// Cumulative scores (may be fractional due to 0.1 per overtrick).
  final Map<String, double> scores;
  final int currentRound;
  final int totalRounds;
  final int? minBid;
  final bool greedPenalty;
  final bool allowCustomTrump;
  final String? currentTrumpSuit;
  final TrumpBidState trumpBidState;

  const GameState({
    required this.roomId,
    required this.phase,
    required this.players,
    required this.myHand,
    this.currentTurn,
    required this.currentTrick,
    required this.scores,
    required this.currentRound,
    required this.totalRounds,
    this.minBid,
    this.greedPenalty = false,
    this.allowCustomTrump = false,
    this.currentTrumpSuit,
    this.trumpBidState = const TrumpBidState(),
  });

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
        roomId: json['roomId'] as String,
        phase: gamePhaseFromString(json['phase'] as String),
        players: (json['players'] as List<dynamic>)
            .map((p) => Player.fromJson(p as Map<String, dynamic>))
            .toList(),
        myHand: (json['myHand'] as List<dynamic>? ?? [])
            .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
            .toList(),
        currentTurn: json['currentTurn'] as String?,
        currentTrick: CurrentTrick.fromJson(
            json['currentTrick'] as Map<String, dynamic>? ?? {}),
        scores: (json['scores'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ),
        currentRound: json['currentRound'] as int? ?? 1,
        totalRounds: json['totalRounds'] as int? ?? 5,
        minBid: json['minBid'] as int?,
        greedPenalty: json['greedPenalty'] as bool? ?? false,
        allowCustomTrump: json['allowCustomTrump'] as bool? ?? false,
        currentTrumpSuit: json['currentTrumpSuit'] as String?,
        trumpBidState: TrumpBidState.fromJson(json['trumpBidState'] as Map<String, dynamic>?),
      );

  /// Whether it is [myPlayerId]'s turn to act.
  bool isMyTurn(String myPlayerId) => currentTurn == myPlayerId;

  /// Whether the game is fully over.
  bool get isGameOver => phase == GamePhase.gameOver;

  @override
  List<Object?> get props => [
        roomId,
        phase,
        players,
        myHand,
        currentTurn,
        currentTrick,
        scores,
        currentRound,
        totalRounds,
        minBid,
        greedPenalty,
        allowCustomTrump,
        currentTrumpSuit,
        trumpBidState,
      ];
}
