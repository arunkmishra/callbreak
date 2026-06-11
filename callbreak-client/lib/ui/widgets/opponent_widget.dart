import 'package:flutter/material.dart';
import '../../data/models/player.dart';
import '../../core/theme.dart';

import '../widgets/turn_timer_widget.dart';

enum OpponentPosition { top, left, right }

/// Displays an opponent's avatar, name, bid/tricks won, and card count.
/// Highlighted when it is that player's turn.
class OpponentWidget extends StatelessWidget {
  final Player player;
  final bool isCurrentTurn;
  final int? turnEndTime;
  final OpponentPosition position;
  final Color accentColor;
  final String? calledTrumpSuit;

  const OpponentWidget({
    super.key,
    required this.player,
    required this.isCurrentTurn,
    this.turnEndTime,
    required this.position,
    this.accentColor = const Color(0xFF2563EB),
    this.calledTrumpSuit,
  });

  @override
  Widget build(BuildContext context) {
    final isVertical = position == OpponentPosition.left || position == OpponentPosition.right;

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrentTurn
            ? Color.lerp(const Color(0xFF0F1B33), accentColor, 0.12)!
            : const Color(0xFF0F1B33),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentTurn
              ? accentColor.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.08),
          width: isCurrentTurn ? 1.5 : 1,
        ),
        boxShadow: isCurrentTurn
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.25),
                  blurRadius: 14,
                  spreadRadius: 2,
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ],
      ),
      child: isVertical ? _buildVertical() : _buildHorizontal(),
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: player.isOnline ? 1.0 : 0.5,
      child: child,
    );
  }

  Widget _buildVertical() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isCurrentTurn && turnEndTime != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: TurnTimerWidget(turnEndTime: turnEndTime!, compact: true),
          ),
        _Avatar(player: player, isCurrentTurn: isCurrentTurn, accentColor: accentColor, calledTrumpSuit: calledTrumpSuit),
        const SizedBox(height: 6),
        _Name(player: player),
        const SizedBox(height: 4),
        _Stats(player: player),
        const SizedBox(height: 4),
        _CardCount(cardCount: player.cardCount),
        const SizedBox(height: 6),
        _FannedBackCards(cardCount: player.cardCount, accentColor: accentColor),
      ],
    );
  }

  Widget _buildHorizontal() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Avatar(player: player, isCurrentTurn: isCurrentTurn, accentColor: accentColor, calledTrumpSuit: calledTrumpSuit),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Name(player: player),
                if (isCurrentTurn && turnEndTime != null) ...[
                  const SizedBox(width: 6),
                  TurnTimerWidget(turnEndTime: turnEndTime!, compact: true),
                ]
              ],
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Stats(player: player),
                const SizedBox(width: 8),
                _CardCount(cardCount: player.cardCount),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final Player player;
  final bool isCurrentTurn;
  final Color accentColor;
  final String? calledTrumpSuit;

  const _Avatar({required this.player, required this.isCurrentTurn, required this.accentColor, this.calledTrumpSuit});

  String _getSuitSymbol(String suit) {
    switch (suit.toLowerCase()) {
      case 'spade': return '♠';
      case 'heart': return '♥';
      case 'diamond': return '♦';
      case 'club': return '♣';
      default: return suit;
    }
  }

  Color _getSuitColor(String suit) {
    return (suit.toLowerCase() == 'heart' || suit.toLowerCase() == 'diamond')
        ? const Color(0xFFEF4444)
        : const Color(0xFF1F2937);
  }

  @override
  Widget build(BuildContext context) {
    Widget avatarContent = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isCurrentTurn
              ? [AppColors.gold, AppColors.goldDark]
              : [accentColor, Color.lerp(accentColor, Colors.black, 0.45)!],
        ),
        boxShadow: [
          BoxShadow(
            color: (isCurrentTurn ? AppColors.gold : accentColor)
                .withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          player.name[0].toUpperCase(),
          style: TextStyle(
            color: isCurrentTurn ? Colors.black87 : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );

    if (calledTrumpSuit != null) {
      avatarContent = Stack(
        clipBehavior: Clip.none,
        children: [
          avatarContent,
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                ],
              ),
              child: Text(
                _getSuitSymbol(calledTrumpSuit!),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.0,
                  color: _getSuitColor(calledTrumpSuit!),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return avatarContent;
  }
}

class _Name extends StatelessWidget {
  final Player player;
  const _Name({required this.player});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                player.name.split(' ').first,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (player.isBot) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B6CC7).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF3B6CC7), width: 0.8),
                ),
                child: const Text(
                  'BOT',
                  style: TextStyle(
                    color: Color(0xFF6FA3F7),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (!player.isOnline) ...[
          const SizedBox(height: 2),
          const Text(
            'OFFLINE',
            style: TextStyle(
              color: AppColors.errorRed,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  final Player player;
  const _Stats({required this.player});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${player.tricksWon} / ${player.bid ?? "?"}',
      style: const TextStyle(
        color: Color(0xFF5B9BF5),
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _CardCount extends StatelessWidget {
  final int cardCount;
  const _CardCount({required this.cardCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.style, color: Colors.white38, size: 12),
        const SizedBox(width: 3),
        Text(
          '$cardCount',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

/// Shows small fanned face-down cards for side opponents.
class _FannedBackCards extends StatelessWidget {
  final int cardCount;
  final Color accentColor;
  const _FannedBackCards({required this.cardCount, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    if (cardCount <= 0) return const SizedBox.shrink();
    final show = cardCount.clamp(1, 5);
    const cardW = 22.0;
    const cardH = 32.0;
    const overlap = 10.0;
    final totalW = (show - 1) * overlap + cardW;
    // Derive a dark shade of the accent for the card back
    final cardDark = Color.lerp(accentColor, Colors.black, 0.65)!;
    final cardLight = Color.lerp(accentColor, Colors.black, 0.45)!;

    return SizedBox(
      width: totalW,
      height: cardH,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(show, (i) {
          return Positioned(
            left: i * overlap.toDouble(),
            top: 0,
            child: Container(
              width: cardW,
              height: cardH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [cardLight, cardDark],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 3,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.shield,
                  size: 10,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
