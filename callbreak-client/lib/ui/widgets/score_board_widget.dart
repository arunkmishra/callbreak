import 'package:flutter/material.dart';
import '../../data/models/game_state.dart';
import '../../data/models/player.dart';
import '../../core/theme.dart';

// ─── Player avatar ────────────────────────────────────────────────────────────

class _PlayerAvatar extends StatelessWidget {
  final Player player;
  final bool isMe;

  const _PlayerAvatar({required this.player, required this.isMe});

  static const List<Color> _palette = [
    Color(0xFF2ECC71), // green
    Color(0xFF3B82F6), // blue
    Color(0xFF8B5CF6), // purple
    Color(0xFF6B7280), // grey
  ];

  Color get _color {
    if (isMe) return const Color(0xFF2ECC71);
    return _palette[player.id.hashCode.abs() % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final initial = (player.name.isNotEmpty ? player.name[0] : '?').toUpperCase();
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
        border: isMe ? Border.all(color: Colors.white, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ─── Inline rank chip (shown in table header) ─────────────────────────────────

/// Shows only the medal / crown emoji — no number chip.
class _RankChip extends StatelessWidget {
  final int rank;
  const _RankChip(this.rank);

  String get _emoji {
    switch (rank) {
      case 1: return '👑';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '🤡';
    }
  }

  @override
  Widget build(BuildContext context) {
    final emoji = _emoji;
    return SizedBox(
      height: 20,
      child: Text(
        emoji,
        style: TextStyle(fontSize: rank == 1 ? 16 : 14),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: Divider(
              color: AppColors.gold.withValues(alpha: 0.3),
              thickness: 1,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              color: AppColors.gold.withValues(alpha: 0.3),
              thickness: 1,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

// ─── Main ScoreBoardWidget ────────────────────────────────────────────────────

class ScoreBoardWidget extends StatelessWidget {
  final GameState gameState;
  final String myPlayerId;
  final bool hideTitle;

  const ScoreBoardWidget({
    super.key,
    required this.gameState,
    required this.myPlayerId,
    this.hideTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final players = gameState.players;
    // Sort by rank; fall back to cumulative score descending.
    final sorted = [...players]..sort((a, b) {
        if (a.rank != null && b.rank != null) return a.rank!.compareTo(b.rank!);
        return b.cumulativeScore.compareTo(a.cumulativeScore);
      });

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1B33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2563EB).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ────────────────────────────────────────────────────
          _SectionHeader(
            label: gameState.isGameOver ? 'FINAL SCORES' : 'ROUND WISE SCORES',
          ),

          // ── Round-wise score table ─────────────────────────────────────
          if (gameState.roundScores.isNotEmpty || sorted.isNotEmpty)
            _RoundScoreTable(
              players: sorted,
              roundScores: gameState.roundScores,
              myPlayerId: myPlayerId,
              showRanks: gameState.isGameOver,
            ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─── Round-wise score table ───────────────────────────────────────────────────

class _RoundScoreTable extends StatelessWidget {
  final List<Player> players; // already sorted
  final List<Map<String, double>> roundScores;
  final String myPlayerId;
  final bool showRanks;

  const _RoundScoreTable({
    required this.players,
    required this.roundScores,
    required this.myPlayerId,
    required this.showRanks,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // ── Header row ───────────────────────────────────────────────
          _TableRow(
            isHeader: true,
            cells: [
              const _TableCell(text: 'ROUND', isHeader: true),
              ...players.map((p) {
                final isMe = p.id == myPlayerId;
                final rank = p.rank ?? (players.indexOf(p) + 1);
                final displayName = isMe ? 'You' : p.name.split(' ').first;
                return _TableCell(
                  isHeader: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // rank badge (only when ranks are available)
                      if (showRanks) _RankChip(rank),
                      if (showRanks) const SizedBox(height: 4),
                      // avatar + name
                      _PlayerAvatar(player: p, isMe: isMe),
                      const SizedBox(height: 4),
                      Text(
                        displayName,
                        style: TextStyle(
                          color: isMe ? const Color(0xFF4ADE80) : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),

          // ── Round rows ───────────────────────────────────────────────
          ...List.generate(roundScores.length, (i) {
            final scoresForRound = roundScores[i];
            return _TableRow(
              isEven: i.isEven,
              cells: [
                _TableCell(text: 'R${i + 1}', isLabel: true),
                ...players.map((p) {
                  final score = scoresForRound[p.id] ?? 0.0;
                  final isMe = p.id == myPlayerId;
                  return _TableCell(
                    text: score.toStringAsFixed(1),
                    isMe: isMe,
                    score: score,
                  );
                }),
              ],
            );
          }),

          // ── Total row ────────────────────────────────────────────────
          _TableRow(
            isTotal: true,
            cells: [
              const _TableCell(
                text: 'TOTAL',
                isLabel: true,
                isTotalLabel: true,
              ),
              ...players.map((p) {
                final score = p.cumulativeScore;
                final isMe = p.id == myPlayerId;
                return _TableCell(
                  text: score.toStringAsFixed(1),
                  isMe: isMe,
                  score: score,
                  isTotalValue: true,
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Table row ────────────────────────────────────────────────────────────────

class _TableRow extends StatelessWidget {
  final List<Widget> cells;
  final bool isHeader;
  final bool isTotal;
  final bool isEven;

  const _TableRow({
    required this.cells,
    this.isHeader = false,
    this.isTotal = false,
    this.isEven = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    if (isHeader) {
      bg = Colors.transparent;
    } else if (isTotal) {
      bg = const Color(0xFF0A1220);
    } else if (isEven) {
      bg = Colors.white.withValues(alpha: 0.03);
    } else {
      bg = Colors.transparent;
    }

    final Border? border = isHeader
        ? Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          )
        : isTotal
            ? Border(
                top: BorderSide(
                  color: AppColors.gold.withValues(alpha: 0.3),
                  width: 1,
                ),
              )
            : null;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: border,
        borderRadius: isTotal
            ? const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              )
            : null,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: cells.map((c) => Expanded(child: c)).toList(),
        ),
      ),
    );
  }
}

// ─── Table cell ───────────────────────────────────────────────────────────────

class _TableCell extends StatelessWidget {
  final String? text;
  final Widget? child;
  final bool isHeader;
  final bool isLabel;
  final bool isTotalLabel;
  final bool isTotalValue;
  final bool isMe;
  final double? score;

  const _TableCell({
    this.text,
    this.child,
    this.isHeader = false,
    this.isLabel = false,
    this.isTotalLabel = false,
    this.isTotalValue = false,
    this.isMe = false,
    this.score,
  });

  Color get _textColor {
    if (isTotalLabel) return AppColors.gold;
    if (isTotalValue) {
      return (score != null && score! < 0) ? AppColors.errorRed : AppColors.gold;
    }
    if (score != null && score! < 0) return AppColors.errorRed;
    if (isMe && score != null && score! >= 0) return const Color(0xFF4ADE80);
    return Colors.white70;
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (child != null) {
      content = child!;
    } else {
      content = Text(
        text ?? '',
        style: TextStyle(
          color: isHeader || isLabel ? Colors.white60 : _textColor,
          fontSize: isTotalValue ? 14 : 13,
          fontWeight: (isTotalLabel || isTotalValue || isHeader)
              ? FontWeight.bold
              : FontWeight.normal,
          letterSpacing: isHeader ? 0.6 : 0,
        ),
        textAlign: TextAlign.center,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Center(child: content),
    );
  }
}
