import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../data/models/player.dart';
import '../widgets/score_board_widget.dart';

class HistoryScorecardScreen extends StatelessWidget {
  final Map<String, dynamic> matchData;

  const HistoryScorecardScreen({super.key, required this.matchData});

  @override
  Widget build(BuildContext context) {
    // Parse participants into Player models
    final participantsData = (matchData['participants'] as List<dynamic>?) ?? [];
    final players = participantsData.map((p) {
      final map = p as Map<String, dynamic>;
      return Player(
        id: map['id'] ?? '',
        name: map['name'] ?? 'Unknown',
        isBot: map['is_bot'] ?? false,
        cumulativeScore: (map['total_score'] as num?)?.toDouble() ?? 0.0,
        rank: map['rank'],
      );
    }).toList();

    // Parse round scores
    final roundScoresData = (matchData['round_scores'] as List<dynamic>?) ?? [];
    final roundScores = roundScoresData.map((rs) {
      final map = rs as Map<String, dynamic>;
      final convertedMap = <String, double>{};
      map.forEach((key, value) {
        convertedMap[key] = (value as num).toDouble();
      });
      return convertedMap;
    }).toList();

    final myPlayerId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final roomId = matchData['room_id'] ?? 'Unknown';

    return Scaffold(
      backgroundColor: const Color(0xFF060F17), // Using table dark bg
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'ROOM: $roomId',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Use the refactored ScoreBoardWidget
              ScoreBoardWidget(
                players: players,
                roundScores: roundScores,
                myPlayerId: myPlayerId,
                isGameOver: true,
                hideTitle: false,
              ),
              const SizedBox(height: 24),
              // Option to share score (similar to GameScreen)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    foregroundColor: const Color(0xFFA78BFA),
                    backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                  ),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  onPressed: () {
                    // Placeholder for sharing functionality in history
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Share functionality coming soon!'),
                        backgroundColor: Color(0xFF7C3AED),
                      )
                    );
                  },
                  label: const Text(
                    'Share Result',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
