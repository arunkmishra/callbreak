import 'package:flutter/material.dart';
import '../../data/models/game_state.dart';
import '../../data/models/player.dart';
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
  final Color accentColor;

  const TrickZoneWidget({
    super.key,
    required this.trick,
    required this.players,
    required this.myPlayerId,
    this.accentColor = const Color(0xFF2563EB),
  });

  @override
  State<TrickZoneWidget> createState() => _TrickZoneWidgetState();
}

class _TrickZoneWidgetState extends State<TrickZoneWidget>
    with SingleTickerProviderStateMixin {
  // Set of playerIds whose card has "arrived" at center (animation done).
  final Set<String> _arrived = {};
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TrickZoneWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // When a new card appears in the trick, it starts at the edge.
    for (final trickCard in widget.trick.cards) {
      if (!_arrived.contains(trickCard.playerId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _arrived.add(trickCard.playerId));
          }
        });
      }
    }

    // Clear arrived state for cards that are no longer in the trick.
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

  static const double _half = 130; // half of 260 (container)
  static const double _cw = 30;    // half card width (60/2)
  static const double _ch = 45;    // half card height (90/2)

  Offset _restOffsetForRelativeIndex(int relativeIndex) {
    switch (relativeIndex) {
      case 0: return const Offset(15, 40);    // bottom-right (me)
      case 1: return const Offset(-55, -5);   // left
      case 2: return const Offset(-10, -50);  // top-left
      case 3: return const Offset(55, -15);   // right
      default: return Offset.zero;
    }
  }

  /// Starting offset (off-screen edge) for the fly-in animation.
  Offset _startOffsetForRelativeIndex(int relativeIndex) {
    switch (relativeIndex) {
      case 0: return const Offset(0, 140);    // flies in from bottom
      case 1: return const Offset(-140, 0);   // flies in from left
      case 2: return const Offset(0, -140);   // flies in from top
      case 3: return const Offset(140, 0);    // flies in from right
      default: return Offset.zero;
    }
  }

  double _rotationForRelativeIndex(int relativeIndex) {
    switch (relativeIndex) {
      case 0: return 0.08;
      case 1: return -0.15;
      case 2: return -0.08;
      case 3: return 0.15;
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
    const double size = 260;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // ── Outer glow ring ────────────────────────────────────
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: const Offset(0, 60), // Push down to true screen center
                child: Container(
                  width: size * 0.80 * _pulseAnimation.value, // Reduced size
                  height: size * 0.50 * _pulseAnimation.value, // Reduced size
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size),
                    border: Border.all(
                      color: widget.accentColor.withValues(alpha: 0.3 * _pulseAnimation.value),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.15 * _pulseAnimation.value),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ── Inner glowing oval ring ──────────────────────────────
          Transform.translate(
            offset: const Offset(0, 60), // Push down to true screen center
            child: Container(
              width: size * 0.65, // Reduced size
              height: size * 0.40, // Reduced size
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size),
                border: Border.all(
                  color: widget.accentColor.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),

          // ── Empty hint ─────────────────────────────────────────────────
          if (widget.trick.isEmpty)
            Center(
              child: Text(
                widget.trick.ledSuit != null
                    ? _suitSymbol(widget.trick.ledSuit!)
                    : '',
                style: const TextStyle(
                  color: Colors.white12,
                  fontSize: 32,
                ),
              ),
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
              left: _half + offset.dx - _cw,
              top: _half + offset.dy - _ch,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: hasArrived ? 1.0 : 0.0,
                child: Transform.scale(
                  scale: 0.85,
                  child: Transform.rotate(
                    angle: _rotationForRelativeIndex(relativeIndex),
                    child: PlayingCardWidget(
                      card: trickCard.card,
                      isSmall: false,
                    ),
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
