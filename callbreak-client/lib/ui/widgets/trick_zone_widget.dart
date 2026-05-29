import 'package:flutter/material.dart';
import '../../data/models/game_state.dart';
import '../../data/models/player.dart';
import '../../core/theme.dart';
import 'playing_card_widget.dart';

/// The center of the table: displays cards played to the current trick.
///
/// Cards animate from the playing player's edge toward center using an
/// implicit animation driven by a StatefulWidget tracking which cards
/// are "arrived" vs. "in-flight".
///
///   [top]
/// [left] [right]
///   [bottom / me]
class TrickZoneWidget extends StatefulWidget {
  final CurrentTrick trick;
  final List<Player> players;
  final String myPlayerId;

  const TrickZoneWidget({
    super.key,
    required this.trick,
    required this.players,
    required this.myPlayerId,
  });

  @override
  State<TrickZoneWidget> createState() => _TrickZoneWidgetState();
}

class _TrickZoneWidgetState extends State<TrickZoneWidget> {
  // Set of playerIds whose card has "arrived" at center (animation done).
  final Set<String> _arrived = {};

  @override
  void didUpdateWidget(covariant TrickZoneWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // When a new card appears in the trick, it starts at the edge.
    // After a short delay we mark it as arrived, triggering the slide.
    for (final trickCard in widget.trick.cards) {
      if (!_arrived.contains(trickCard.playerId)) {
        // Schedule arrival after one frame so the initial (off-center) position
        // is rendered first, allowing the animation to play.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _arrived.add(trickCard.playerId));
          }
        });
      }
    }

    // Clear arrived state for cards that are no longer in the trick
    // (trick was collected).
    final currentIds = widget.trick.cards.map((tc) => tc.playerId).toSet();
    _arrived.removeWhere((id) => !currentIds.contains(id));
  }

  int _getRelativeIndex(String playerId) {
    if (widget.players.isEmpty) return 0;
    final myIndex = widget.players.indexWhere((p) => p.id == widget.myPlayerId);
    final playerIndex = widget.players.indexWhere((p) => p.id == playerId);
    if (myIndex == -1 || playerIndex == -1) return 0;
    return (playerIndex - myIndex + widget.players.length) % widget.players.length;
  }

  // ── Rest positions — spread cards far enough to avoid overlap ───────────────
  //
  // Container is 240×240. Card size (isSmall) = 52×78.
  // Half-card = 26w / 39h. Center = (120, 120).
  //
  //  • Bottom (me):  card top-left at (center.x-26, center.y+30) → bottom
  //  • Left:         card top-left at (center.x-86, center.y-39) → left
  //  • Top:          card top-left at (center.x-26, center.y-108) → top
  //  • Right:        card top-left at (center.x+34, center.y-39) → right
  //
  // Using offsets relative to center for AnimatedPositioned:
  //   left = half + dx - halfCardW  |  top = half + dy - halfCardH
  static const double _half = 120; // half of 240
  static const double _cw = 26;    // half card width (52/2)
  static const double _ch = 39;    // half card height (78/2)

  /// Final resting offset (dx, dy) relative to the container's center.
  Offset _restOffsetForRelativeIndex(int relativeIndex) {
    switch (relativeIndex) {
      case 0: return const Offset(0, 52);    // bottom (me) — below center
      case 1: return const Offset(-58, 0);   // left
      case 2: return const Offset(0, -52);   // top — above center
      case 3: return const Offset(58, 0);    // right
      default: return Offset.zero;
    }
  }

  /// Starting offset (off-screen edge) for the fly-in animation.
  Offset _startOffsetForRelativeIndex(int relativeIndex) {
    switch (relativeIndex) {
      case 0: return const Offset(0, 130);    // flies in from bottom
      case 1: return const Offset(-130, 0);   // flies in from left
      case 2: return const Offset(0, -130);   // flies in from top
      case 3: return const Offset(130, 0);    // flies in from right
      default: return Offset.zero;
    }
  }

  double _rotationForRelativeIndex(int relativeIndex) {
    switch (relativeIndex) {
      case 0: return 0.0;
      case 1: return -0.12;
      case 2: return 0.0;
      case 3: return 0.12;
      default: return 0.0;
    }
  }

  String _suitSymbol(String suit) {
    switch (suit) {
      case 'Spade':   return '♠';
      case 'Heart':   return '♥';
      case 'Diamond': return '♦';
      case 'Club':    return '♣';
      default:        return '?';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Larger container so spread-out cards don't clip
    const double size = 240;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Table circle (decorative) ──────────────────────────────────
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.tableGreen.withValues(alpha: 0.5),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: widget.trick.isEmpty
                ? Center(
                    child: Text(
                      widget.trick.ledSuit != null
                          ? _suitSymbol(widget.trick.ledSuit!)
                          : '♠♥♦♣',
                      style: const TextStyle(
                        color: Colors.white12,
                        fontSize: 32,
                      ),
                    ),
                  )
                : null,
          ),

          // ── Played cards ───────────────────────────────────────────────
          ...widget.trick.cards.map((trickCard) {
            final int relativeIndex = _getRelativeIndex(trickCard.playerId);
            final bool hasArrived = _arrived.contains(trickCard.playerId);

            final Offset offset = hasArrived
                ? _restOffsetForRelativeIndex(relativeIndex)
                : _startOffsetForRelativeIndex(relativeIndex);

            return AnimatedPositioned(
              key: ValueKey(trickCard.playerId),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              // Center card around its rest position
              left: _half + offset.dx - _cw,
              top: _half + offset.dy - _ch,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: hasArrived ? 1.0 : 0.0,
                child: Transform.rotate(
                  angle: _rotationForRelativeIndex(relativeIndex),
                  child: PlayingCardWidget(
                    card: trickCard.card,
                    isSmall: true,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
