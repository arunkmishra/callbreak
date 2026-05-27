import 'package:flutter/material.dart';
import '../../data/models/player.dart';
import '../../core/theme.dart';

enum OpponentPosition { top, left, right }

/// Displays an opponent's avatar, name, bid/tricks won, and card count.
/// Highlighted when it is that player's turn.
class OpponentWidget extends StatelessWidget {
  final Player player;
  final bool isCurrentTurn;
  final OpponentPosition position;

  const OpponentWidget({
    super.key,
    required this.player,
    required this.isCurrentTurn,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    final isVertical = position == OpponentPosition.top;

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isCurrentTurn
            ? AppColors.gold.withValues(alpha: 0.15)
            : Colors.black38,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentTurn ? AppColors.gold : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: isCurrentTurn
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: isVertical
          ? _buildVertical()
          : _buildHorizontal(),
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
        _Avatar(player: player, isCurrentTurn: isCurrentTurn),
        const SizedBox(height: 6),
        _Name(player: player),
        const SizedBox(height: 4),
        _Stats(player: player),
        const SizedBox(height: 4),
        _CardCount(cardCount: player.cardCount),
      ],
    );
  }

  Widget _buildHorizontal() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Avatar(player: player, isCurrentTurn: isCurrentTurn),
        const SizedBox(height: 4),
        _Name(player: player),
        const SizedBox(height: 2),
        _Stats(player: player),
        const SizedBox(height: 2),
        _CardCount(cardCount: player.cardCount),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final Player player;
  final bool isCurrentTurn;

  const _Avatar({required this.player, required this.isCurrentTurn});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor:
          isCurrentTurn ? AppColors.gold : AppColors.tableGreenLight,
      child: Text(
        player.name[0].toUpperCase(),
        style: TextStyle(
          color: isCurrentTurn ? Colors.black87 : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
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
                  color: AppColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.gold, width: 0.5),
                ),
                child: const Text(
                  'BOT',
                  style: TextStyle(color: AppColors.gold, fontSize: 8, fontWeight: FontWeight.bold),
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
        color: AppColors.gold,
        fontSize: 12,
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
        const Icon(Icons.style, color: Colors.white54, size: 12),
        const SizedBox(width: 3),
        Text(
          '$cardCount',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}
