import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';

class RemoteLogger {
  // We use an explicit HTTP client so we can mock it in tests.
  static http.Client? httpClient;
  static String? currentUsername;

  static void logError(Object error, StackTrace? stackTrace) {
    try {
      final platform = kIsWeb ? 'Web' : 'Android';
      final payload = {
        'platform': platform,
        if (currentUsername != null) 'username': currentUsername,
        'message': error.toString(),
        'stackTrace': stackTrace?.toString(),
      };

      final client = httpClient ?? http.Client();
      client.post(
        Uri.parse('$kHttpBaseUrl/api/logs/frontend'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).then((_) {}, onError: (e) {
        // Silently fail to avoid infinite error loops if the backend is down
        debugPrint('Failed to send remote log: $e');
      });
    } catch (e) {
      debugPrint('Failed to serialize remote log payload: $e');
    }
  }
}
