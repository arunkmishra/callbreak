import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';

/// Sends a heartbeat to the backend every 20 seconds so the server
/// knows this user is currently online.
///
/// The backend sets a Redis key `online:<userId>` with a 35-second TTL.
/// When the app closes and heartbeats stop, Redis automatically expires
/// the key, marking the user as offline.
class HeartbeatService {
  Timer? _timer;
  static const _intervalSeconds = 20;

  /// Starts the heartbeat. Call this when the user is authenticated.
  void start() {
    stop(); // Cancel any existing timer first
    _sendHeartbeat(); // Send immediately on start
    _timer = Timer.periodic(
      const Duration(seconds: _intervalSeconds),
      (_) => _sendHeartbeat(),
    );
    debugPrint('💓 HeartbeatService started');
  }

  /// Stops the heartbeat. Call this on logout or app close.
  void stop() {
    _timer?.cancel();
    _timer = null;
    debugPrint('💓 HeartbeatService stopped');
  }

  bool get isRunning => _timer != null;

  Future<void> _sendHeartbeat() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      stop(); // User logged out, stop heartbeat
      return;
    }

    try {
      final token = session.accessToken;
      final response = await http.post(
        Uri.parse('$kHttpBaseUrl/api/users/heartbeat'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode != 200) {
        debugPrint('💓 Heartbeat failed: ${response.statusCode}. Response: ${response.body}');
      }
    } catch (e) {
      debugPrint('💓 Heartbeat error: $e');
    }
  }

  /// Fetches the list of currently online user IDs from the backend.
  static Future<List<String>> getOnlineUserIds() async {
    try {
      final response = await http.get(
        Uri.parse('$kHttpBaseUrl/api/users/online'),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final ids = json['onlineUserIds'] as List<dynamic>?;
        return ids?.map((e) => e.toString()).toList() ?? [];
      }
    } catch (e) {
      debugPrint('Failed to fetch online users: $e');
    }
    return [];
  }
}
