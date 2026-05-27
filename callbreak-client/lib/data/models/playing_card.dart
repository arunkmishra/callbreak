import 'package:equatable/equatable.dart';

/// Represents a single playing card.
///
/// [suit] is one of: "Spade", "Heart", "Diamond", "Club"
/// [rank] is one of: "2"–"10", "J", "Q", "K", "A"
/// [value] is the numeric rank value (2–14) for comparison.
class PlayingCard extends Equatable implements Comparable<PlayingCard> {
  final String suit;
  final String rank;
  final int value;

  const PlayingCard({
    required this.suit,
    required this.rank,
    required this.value,
  });

  factory PlayingCard.fromJson(Map<String, dynamic> json) {
    final rawSuit = json['suit'] as String;
    final rawRank = json['rank'];
    
    final suit = _normalizeSuit(rawSuit);
    final rank = _normalizeRank(rawRank);
    
    return PlayingCard(
      suit: suit,
      rank: rank,
      value: json['value'] as int? ?? _rankToValue(rank),
    );
  }

  Map<String, dynamic> toJson() => {
        'suit': suit,
        'rank': rank,
        'value': value,
      };

  /// Convenience getter for display (e.g., "A♠")
  String get display => '$rank${_suitSymbol(suit)}';

  static String _suitSymbol(String suit) {
    switch (suit) {
      case 'Spade':
        return '♠';
      case 'Heart':
        return '♥';
      case 'Diamond':
        return '♦';
      case 'Club':
        return '♣';
      default:
        return suit[0];
    }
  }

  static String _normalizeSuit(String s) {
    if (s.toUpperCase() == 'SPADE') return 'Spade';
    if (s.toUpperCase() == 'HEART') return 'Heart';
    if (s.toUpperCase() == 'DIAMOND') return 'Diamond';
    if (s.toUpperCase() == 'CLUB') return 'Club';
    return s;
  }

  static String _normalizeRank(dynamic r) {
    if (r is Map) return r['displayName'] as String;
    final s = (r as String).toUpperCase();
    switch (s) {
      case 'TWO': return '2';
      case 'THREE': return '3';
      case 'FOUR': return '4';
      case 'FIVE': return '5';
      case 'SIX': return '6';
      case 'SEVEN': return '7';
      case 'EIGHT': return '8';
      case 'NINE': return '9';
      case 'TEN': return '10';
      case 'JACK': return 'J';
      case 'QUEEN': return 'Q';
      case 'KING': return 'K';
      case 'ACE': return 'A';
      default: return s;
    }
  }

  static int _rankToValue(String r) {
    switch (r) {
      case 'A': return 14;
      case 'K': return 13;
      case 'Q': return 12;
      case 'J': return 11;
      default: return int.tryParse(r) ?? 2;
    }
  }

  bool get isSpade => suit == 'Spade';
  bool get isRedSuit => suit == 'Heart' || suit == 'Diamond';

  @override
  List<Object?> get props => [suit, rank];

  @override
  int compareTo(PlayingCard other) {
    int suitWeight(String suit) {
      switch (suit) {
        case 'Spade': return 4;
        case 'Heart': return 3;
        case 'Club': return 2;
        case 'Diamond': return 1;
        default: return 0;
      }
    }
    int suitDiff = suitWeight(suit).compareTo(suitWeight(other.suit));
    if (suitDiff != 0) return -suitDiff; // Higher suit weight first
    return -value.compareTo(other.value); // Higher rank value first
  }
}
