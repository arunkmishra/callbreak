import 'package:shared_preferences/shared_preferences.dart';

class StatsPrefs {
  static const _kGamesPlayed = 'stats_games_played';
  static const _kGamesWon = 'stats_games_won';
  static const _kTotalPoints = 'stats_total_points';

  static Future<Map<String, dynamic>> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final played = prefs.getInt(_kGamesPlayed) ?? 0;
    final won = prefs.getInt(_kGamesWon) ?? 0;
    final points = prefs.getDouble(_kTotalPoints) ?? 0.0;
    
    final winRate = played > 0 ? (won / played) * 100 : 0.0;
    
    return {
      'played': played,
      'won': won,
      'points': points,
      'winRate': winRate,
    };
  }

  static Future<void> recordGame({required bool won, required double points}) async {
    final prefs = await SharedPreferences.getInstance();
    final played = prefs.getInt(_kGamesPlayed) ?? 0;
    final currentWon = prefs.getInt(_kGamesWon) ?? 0;
    final currentPoints = prefs.getDouble(_kTotalPoints) ?? 0.0;
    
    await prefs.setInt(_kGamesPlayed, played + 1);
    if (won) {
      await prefs.setInt(_kGamesWon, currentWon + 1);
    }
    await prefs.setDouble(_kTotalPoints, currentPoints + points);
  }
}
