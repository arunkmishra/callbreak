import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight client-side persistence for the player's display name.
///
/// Uses [SharedPreferences] so the name survives app restarts without
/// needing an account or a database.  Replace this with a proper auth
/// service later — the call sites in [HomeScreen] won't need to change.
class PlayerPrefs {
  static const _kPlayerName = 'player_name';

  /// Returns the saved name, or `null` if none has been saved yet.
  static Future<String?> loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kPlayerName);
    return (name != null && name.trim().isNotEmpty) ? name.trim() : null;
  }

  /// Persists [name] so it can be restored on next launch.
  static Future<void> saveName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPlayerName, trimmed);
  }

  /// Clears the stored name (useful for a future "sign out" flow).
  static Future<void> clearName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPlayerName);
  }
}
