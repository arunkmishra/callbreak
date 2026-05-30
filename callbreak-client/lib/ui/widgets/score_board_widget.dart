import 'package:flutter/material.dart';
import '../../data/models/game_state.dart';
import '../../core/theme.dart';

class ScoreBoardWidget extends StatelessWidget {
  final GameState gameState;
  final bool hideTitle;

  const ScoreBoardWidget({super.key, required this.gameState, this.hideTitle = false});

  @override
  Widget build(BuildContext context) {
    final players = gameState.players;
    final roundScores = gameState.roundScores;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hideTitle) ...[
            const Text(
              'Scoreboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            child: DataTable(
              columnSpacing: 16,
              horizontalMargin: 12,
              headingRowHeight: 40,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 36,
              headingRowColor: WidgetStateProperty.all(AppColors.tableGreenLight),
              dataRowColor: WidgetStateProperty.all(Colors.black12),
              columns: [
                const DataColumn(label: Text('Round', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                ...players.map((p) {
                  final name = p.name.split(' ').first;
                  String rankStr = '';
                  if (gameState.phase.name == 'gameOver' && p.rank != null) {
                    if (p.rank == 1) { rankStr = '🥇 '; }
                    else if (p.rank == 2) { rankStr = '🥈 '; }
                    else if (p.rank == 3) { rankStr = '🥉 '; }
                    else { rankStr = '🤡 '; }
                  }
                  return DataColumn(
                    label: Container(
                      constraints: const BoxConstraints(minWidth: 45),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$rankStr$name',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  );
                }),
              ],
              rows: [
                // Render each round's score
                ...List.generate(roundScores.length, (index) {
                  final roundIndex = index + 1;
                  final scoresForRound = roundScores[index];
                  
                  return DataRow(
                    cells: [
                      DataCell(
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('R$roundIndex', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ),
                      ),
                      ...players.map((p) {
                        final score = scoresForRound[p.id] ?? 0.0;
                        return DataCell(
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              score.toStringAsFixed(1),
                              style: TextStyle(
                                color: score < 0 ? AppColors.errorRed : Colors.white,
                                fontWeight: score < 0 ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }),
                // Total Score Row
                DataRow(
                  color: WidgetStateProperty.all(Colors.black38),
                  cells: [
                    DataCell(
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Total', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                    ...players.map((p) {
                      final score = p.cumulativeScore;
                      return DataCell(
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            score.toStringAsFixed(1),
                            style: TextStyle(
                              color: score < 0 ? AppColors.errorRed : AppColors.gold,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
