import 'dart:convert';
import 'package:http/http.dart' as http;

/// Result of a room creation or join operation.
class RoomJoinResult {
  final String roomId;
  final String playerId;
  final String sessionToken;

  const RoomJoinResult({
    required this.roomId,
    required this.playerId,
    required this.sessionToken,
  });
}

/// Handles HTTP REST calls to the Callbreak backend.
class ApiRepository {
  final String baseUrl;
  final http.Client _client;

  ApiRepository({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// POST /api/rooms/create
  ///
  /// Creates a new room and returns the room code + host player ID.
  /// Throws [ApiException] on non-2xx response or network error.
  Future<RoomJoinResult> createRoom(String playerName, String? playerId, {int totalRounds = 5, int? minBid, bool greedPenalty = false, bool allowCustomTrump = false}) async {
    final body = {
      'playerName': playerName,
      'totalRounds': totalRounds,
      'greedPenalty': greedPenalty,
      'allowCustomTrump': allowCustomTrump,
    };
    if (playerId != null) {
      body['playerId'] = playerId;
    }
    if (minBid != null) {
      body['minBid'] = minBid;
    }

    final response = await _client.post(
      Uri.parse('$baseUrl/api/rooms/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    _assertSuccess(response, 'Create room');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return RoomJoinResult(
      roomId: json['roomId'] as String,
      playerId: json['playerId'] as String,
      sessionToken: json['sessionToken'] as String,
    );
  }

  /// POST /api/rooms/join
  ///
  /// Joins an existing room by its 5-letter code.
  /// Throws [ApiException] on non-2xx response or network error.
  Future<RoomJoinResult> joinRoom(String roomId, String playerName, String? playerId) async {
    final body = {
      'roomId': roomId.toUpperCase(),
      'playerName': playerName,
    };
    if (playerId != null) {
      body['playerId'] = playerId;
    }
    
    final response = await _client.post(
      Uri.parse('$baseUrl/api/rooms/join'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    _assertSuccess(response, 'Join room');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return RoomJoinResult(
      roomId: json['roomId'] as String,
      playerId: json['playerId'] as String,
      sessionToken: json['sessionToken'] as String,
    );
  }

  void _assertSuccess(http.Response response, String operation) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = '$operation failed (${response.statusCode})';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = body['error'] as String? ?? message;
      } catch (_) {}
      throw ApiException(message, response.statusCode);
    }
  }

  void dispose() => _client.close();
}

/// Thrown when the server returns a non-2xx response.
class ApiException implements Exception {
  final String message;
  final int statusCode;

  const ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
