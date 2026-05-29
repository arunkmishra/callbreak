import 'package:flutter/material.dart';
import '../../core/theme.dart';

class StatsDialog extends StatelessWidget {
  final Map<String, dynamic> stats;

  const StatsDialog({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final played = stats['played'] as int;
    final won = stats['won'] as int;
    final winRate = stats['winRate'] as double;
    final points = stats['points'] as double;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Your Stats',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _StatRow(label: 'Games Played', valueText: '$played', valueColor: Colors.white),
            const SizedBox(height: 16),
            _StatRow(label: 'Games Won', valueText: '$won', valueColor: AppColors.successGreen),
            const SizedBox(height: 16),
            _StatRow(label: 'Win Rate', valueText: '${winRate.toStringAsFixed(1)}%', valueColor: AppColors.gold),
            const SizedBox(height: 16),
            _StatRow(
              label: 'Total Points',
              valueText: points.toStringAsFixed(points.truncateToDouble() == points ? 0 : 1),
              valueColor: Colors.white,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String valueText;
  final Color valueColor;

  const _StatRow({
    required this.label,
    required this.valueText,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
        ),
        Text(
          valueText,
          style: TextStyle(
            color: valueColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
