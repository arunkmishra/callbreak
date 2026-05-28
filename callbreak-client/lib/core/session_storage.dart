import 'package:shared_preferences/shared_preferences.dart';

/// Persists the player's active session across app restarts and process kills.
///
/// Stored keys are cleared on intentional disconnect or game over, so storage
/// never accumulates stale data.
class SessionStorage {
  static const _keyRoomId = 'session_roomId';
  static const _keyPlayerId = 'session_playerId';
  static const _keySessionToken = 'session_token';

  /// Saves the session details to persistent storage.
  Future<void> save({
    required String roomId,
    required String playerId,
    required String sessionToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRoomId, roomId);
    await prefs.setString(_keyPlayerId, playerId);
    await prefs.setString(_keySessionToken, sessionToken);
  }

  /// Returns the saved session, or null if none exists.
  Future<SavedSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final roomId = prefs.getString(_keyRoomId);
    final playerId = prefs.getString(_keyPlayerId);
    final sessionToken = prefs.getString(_keySessionToken);

    if (roomId == null || playerId == null || sessionToken == null) return null;
    return SavedSession(
      roomId: roomId,
      playerId: playerId,
      sessionToken: sessionToken,
    );
  }

  /// Clears the saved session (call on intentional disconnect or game over).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRoomId);
    await prefs.remove(_keyPlayerId);
    await prefs.remove(_keySessionToken);
  }
}

class SavedSession {
  final String roomId;
  final String playerId;
  final String sessionToken;

  const SavedSession({
    required this.roomId,
    required this.playerId,
    required this.sessionToken,
  });
}
