import 'package:equatable/equatable.dart';

/// A player in the Callbreak room.
class Player extends Equatable {
  final String id;
  final String name;

  /// Bid placed for this round. Null during LOBBY phase.
  final int? bid;

  /// Number of tricks won so far this round.
  final int tricksWon;

  /// Number of cards remaining in hand (visible to all players).
  final int cardCount;

  /// Cumulative score across all rounds.
  final double cumulativeScore;

  final bool isOnline;
  final bool isBot;
  final int? rank;
  final int? currentRp;
  final int? rpChange;

  const Player({
    required this.id,
    required this.name,
    this.bid,
    this.tricksWon = 0,
    this.cardCount = 0,
    this.cumulativeScore = 0.0,
    this.isOnline = true,
    this.isBot = false,
    this.rank,
    this.currentRp,
    this.rpChange,
  });

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        name: json['name'] as String,
        bid: json['bid'] as int?,
        tricksWon: json['tricksWon'] as int? ?? 0,
        cardCount: json['cardCount'] as int? ?? 0,
        cumulativeScore: (json['cumulativeScore'] as num?)?.toDouble() ?? 0.0,
        isOnline: json['isOnline'] as bool? ?? true,
        isBot: json['isBot'] as bool? ?? false,
        rank: json['rank'] as int?,
        currentRp: json['currentRp'] as int?,
        rpChange: json['rpChange'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'bid': bid,
        'tricksWon': tricksWon,
        'cardCount': cardCount,
        'cumulativeScore': cumulativeScore,
        'isOnline': isOnline,
        'isBot': isBot,
        'rank': rank,
        'currentRp': currentRp,
        'rpChange': rpChange,
      };

  @override
  List<Object?> get props => [id, name, bid, tricksWon, cardCount, cumulativeScore, isOnline, isBot, rank, currentRp, rpChange];
}
