import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/playing_card.dart';

/// Renders a single playing card visually.
///
/// Jack, Queen and King cards use traditional face card images from
/// [assets/face_cards/]. All other cards are drawn programmatically.
///
/// [isPlayable] controls the gold glow/highlight effect.
/// [isSmall] reduces size for compact displays (e.g. trick zone).
class PlayingCardWidget extends StatefulWidget {
  final PlayingCard card;
  final bool isPlayable;
  final bool isSmall;
  final bool faceDown;
  final VoidCallback? onTap;

  const PlayingCardWidget({
    super.key,
    required this.card,
    this.isPlayable = false,
    this.isSmall = false,
    this.faceDown = false,
    this.onTap,
  });

  @override
  State<PlayingCardWidget> createState() => _PlayingCardWidgetState();
}

class _PlayingCardWidgetState extends State<PlayingCardWidget> {
  bool _hovered = false;

  bool get _isFaceCard =>
      widget.card.rank == 'J' ||
      widget.card.rank == 'Q' ||
      widget.card.rank == 'K';

  @override
  Widget build(BuildContext context) {
    if (widget.faceDown) return _buildFaceDown();
    if (_isFaceCard) return _buildFaceCard();
    return _buildNumberCard();
  }

  // ── Number / Ace card ───────────────────────────────────────────────────────

  Widget _buildNumberCard() {
    final double w = widget.isSmall ? 52 : 72;
    final double h = widget.isSmall ? 78 : 108;
    final Color rankColor =
        widget.card.isRedSuit ? AppColors.rankRed : AppColors.rankBlack;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _hovered = true),
      onTapUp: (_) => setState(() => _hovered = false),
      onTapCancel: () => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(widget.isSmall ? 8 : 12),
          border: Border.all(
            color: widget.isPlayable ? AppColors.gold : Colors.grey.shade300,
            width: widget.isPlayable ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isPlayable
                  ? AppColors.gold.withValues(alpha: _hovered ? 0.6 : 0.3)
                  : Colors.black38,
              blurRadius: widget.isPlayable ? 12 : 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.card.rank,
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.w900,
                  fontSize: widget.isSmall ? 14 : 18,
                  height: 1,
                ),
              ),
              Text(
                _suitSymbol(widget.card.suit),
                style: TextStyle(
                  color: rankColor,
                  fontSize: widget.isSmall ? 10 : 14,
                  height: 1,
                ),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.center,
                child: Text(
                  _suitSymbol(widget.card.suit),
                  style: TextStyle(
                    color: rankColor,
                    fontSize: widget.isSmall ? 22 : 32,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Face card (J / Q / K) — uses static image asset ────────────────────────

  Widget _buildFaceCard() {
    final double w = widget.isSmall ? 52 : 72;
    final double h = widget.isSmall ? 78 : 108;
    final String assetPath = _faceCardAsset(widget.card.rank, widget.card.suit);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _hovered = true),
      onTapUp: (_) => setState(() => _hovered = false),
      onTapCancel: () => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(widget.isSmall ? 8 : 12),
          border: Border.all(
            color: widget.isPlayable ? AppColors.gold : Colors.grey.shade300,
            width: widget.isPlayable ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isPlayable
                  ? AppColors.gold.withValues(alpha: _hovered ? 0.7 : 0.35)
                  : Colors.black38,
              blurRadius: widget.isPlayable ? 14 : 4,
              spreadRadius: widget.isPlayable ? 1 : 0,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.isSmall ? 6 : 10),
          child: Stack(
            children: [
              // ── Instant text placeholder (always rendered underneath) ──
              // Visible immediately — no waiting for asset. If the image loads
              // successfully this gets covered; if it fails it stays visible.
              _FaceCardTextFallback(
                rank: widget.card.rank,
                suit: widget.card.suit,
                width: w,
                height: h,
                isSmall: widget.isSmall,
              ),

              // ── Face card image with crossfade on load ──────────────────
              Image.asset(
                assetPath,
                width: w,
                height: h,
                fit: BoxFit.fill,
                // Crossfade from transparent → opaque once first frame renders
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) {
                    return child; // already in memory — show instantly
                  }
                  return AnimatedOpacity(
                    opacity: frame == null ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeIn,
                    child: child,
                  );
                },
                // If asset is missing or corrupt, show nothing (fallback underneath shows)
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Face-down card ──────────────────────────────────────────────────────────

  Widget _buildFaceDown() {
    final double w = widget.isSmall ? 52 : 72;
    final double h = widget.isSmall ? 78 : 108;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.isSmall ? 8 : 12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
        ),
        border: Border.all(color: Colors.white24),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 3)),
        ],
      ),
      child: const Center(
        child: Icon(Icons.style_rounded, color: Colors.white24, size: 28),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Returns the asset path for the given face card rank + suit.
  static String _faceCardAsset(String rank, String suit) {
    final r = rank.toLowerCase(); // j, q, k
    final s = switch (suit) {
      'Spade' => 'spades',
      'Heart' => 'hearts',
      'Diamond' => 'diamonds',
      'Club' => 'clubs',
      _ => 'spades',
    };
    return 'assets/face_cards/${r}_$s.png';
  }

  String _suitSymbol(String suit) {
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Text-based fallback for face cards (J / Q / K)
//
// Renders immediately so the player can always see rank + suit while the
// image asset is being fetched from disk/cache. The image is layered on top
// and fades in once ready; if it never loads this stays visible.
// ─────────────────────────────────────────────────────────────────────────────

class _FaceCardTextFallback extends StatelessWidget {
  final String rank;
  final String suit;
  final double width;
  final double height;
  final bool isSmall;

  const _FaceCardTextFallback({
    required this.rank,
    required this.suit,
    required this.width,
    required this.height,
    required this.isSmall,
  });

  Color get _suitColor {
    switch (suit) {
      case 'Heart':
      case 'Diamond':
        return AppColors.rankRed;
      default:
        return AppColors.rankBlack;
    }
  }

  String get _suitSymbol {
    switch (suit) {
      case 'Spade':   return '♠';
      case 'Heart':   return '♥';
      case 'Diamond': return '♦';
      case 'Club':    return '♣';
      default:        return suit[0];
    }
  }

  @override
  Widget build(BuildContext context) {
    final rankFontSize = isSmall ? 15.0 : 20.0;
    final suitFontSize = isSmall ? 11.0 : 15.0;
    final centerFontSize = isSmall ? 20.0 : 30.0;
    final color = _suitColor;
    final symbol = _suitSymbol;

    return Container(
      width: width,
      height: height,
      color: AppColors.cardWhite,
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top-left rank + suit
          Text(
            rank,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: rankFontSize,
              height: 1,
            ),
          ),
          Text(
            symbol,
            style: TextStyle(color: color, fontSize: suitFontSize, height: 1),
          ),
          // Center large suit
          Expanded(
            child: Center(
              child: Text(
                symbol,
                style: TextStyle(color: color, fontSize: centerFontSize),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
