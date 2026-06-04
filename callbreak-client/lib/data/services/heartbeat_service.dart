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
  static final HeartbeatService _instance = HeartbeatService._internal();
  factory HeartbeatService() => _instance;
  HeartbeatService._internal();

  Timer? _timer;
  static const _intervalSeconds = 20;
  static String currentStatus = 'available';

  /// Initializes the heartbeat listener to start/stop automatically on auth changes.
  static void initialize() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        if (!_instance.isRunning) _instance.start();
      } else {
        _instance.stop();
      }
    });
  }

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
        body: jsonEncode({'status': currentStatus}),
      );
      if (response.statusCode != 200) {
        debugPrint('💓 Heartbeat failed: ${response.statusCode}. Response: ${response.body}');
        if (response.statusCode == 401) {
          try {
            await Supabase.instance.client.auth.refreshSession();
            final newSession = Supabase.instance.client.auth.currentSession;
            if (newSession != null) {
              final newToken = newSession.accessToken;
              await http.post(
                Uri.parse('$kHttpBaseUrl/api/users/heartbeat'),
                headers: {
                  'Authorization': 'Bearer $newToken',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({'status': currentStatus}),
              );
              debugPrint('💓 Heartbeat retried successfully after refresh');
            }
          } catch (refreshErr) {
            debugPrint('💓 Heartbeat token refresh failed: $refreshErr');
          }
        }
      }
    } catch (e) {
      debugPrint('💓 Heartbeat error: $e');
    }
  }

  /// Fetches the list of currently online user IDs and their statuses from the backend.
  static Future<Map<String, String>> getOnlineUsers() async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$kHttpBaseUrl/api/users/online?_t=$ts'),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final statuses = json['userStatuses'] as Map<String, dynamic>?;
        if (statuses != null) {
          return statuses.map((k, v) => MapEntry(k, v.toString()));
        }
        final ids = json['onlineUserIds'] as List<dynamic>?;
        return { for (var id in ids ?? []) id.toString(): 'available' };
      }
    } catch (e) {
      debugPrint('Failed to fetch online users: $e');
    }
    return {};
  }
}
