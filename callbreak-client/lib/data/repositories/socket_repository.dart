import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/game_state.dart';

/// Reconnect status events surfaced to the BLoC.
enum ReconnectStatus { reconnecting, reconnected, failed }

/// Manages the WebSocket connection to the Callbreak server.
///
/// Features:
/// - [connect] opens the socket and exposes a [Stream<GameState>].
/// - Auto-reconnect on unexpected close with exponential backoff.
/// - [reconnectStatusStream] lets the BLoC show/hide a "Reconnecting…" banner.
/// - [disconnect] stops all retries and closes cleanly.
class SocketRepository {
  final String wsBaseUrl;

  WebSocketChannel? _channel;
  StreamController<GameState>? _controller;
  final _reconnectStatusController =
      StreamController<ReconnectStatus>.broadcast();

  // ── Reconnect state ────────────────────────────────────────────────────────
  bool _intentionalDisconnect = false;
  bool _isReconnecting = false;
  String? _lastRoomId;
  String? _lastPlayerId;
  String? _lastSessionToken;

  static const _maxRetries = 10;
  static const _initialBackoffMs = 1000;
  static const _maxBackoffMs = 30000;

  SocketRepository({required this.wsBaseUrl});

  /// Stream of reconnect lifecycle events for UI feedback.
  Stream<ReconnectStatus> get reconnectStatusStream =>
      _reconnectStatusController.stream;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Connects to the room and returns a broadcast [Stream<GameState>].
  Stream<GameState> connect(
      String roomId, String playerId, String sessionToken) {
    _intentionalDisconnect = false;
    _lastRoomId = roomId;
    _lastPlayerId = playerId;
    _lastSessionToken = sessionToken;

    _controller ??= StreamController<GameState>.broadcast();
    _openSocket(roomId, playerId, sessionToken);
    return _controller!.stream;
  }

  /// Sends a typed action to the server.
  void sendAction(String actionType, [Map<String, dynamic>? payload]) {
    if (_channel == null) return;
    final message = <String, dynamic>{'type': actionType, ...?payload};
    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (_) {
      // Socket not ready; reconnect will handle it
    }
  }

  /// Closes the WebSocket and stops all reconnect attempts.
  void disconnect() {
    _intentionalDisconnect = true;
    _isReconnecting = false;
    _closeSocket();
    _controller?.close();
    _controller = null;
    _lastRoomId = null;
    _lastPlayerId = null;
    _lastSessionToken = null;
  }

  bool get isConnected => _channel != null;

  // ── Internal ───────────────────────────────────────────────────────────────

  void _openSocket(String roomId, String playerId, String sessionToken) {
    _closeSocket(); // Close any stale channel first

    final uri = Uri.parse(
        '$wsBaseUrl/ws/rooms/${roomId.toUpperCase()}?playerId=$playerId&sessionToken=$sessionToken');

    try {
      _channel = WebSocketChannel.connect(uri);
    } catch (e) {
      _scheduleReconnect();
      return;
    }

    _channel!.stream.listen(
      (dynamic raw) {
        // Got a message — we're definitely connected
        if (_isReconnecting) {
          _isReconnecting = false;
          _reconnectStatusController.add(ReconnectStatus.reconnected);
        }
        _handleMessage(raw);
      },
      onError: (Object error) {
        print('🔌 WS stream error: $error');
        if (error is ServerError) {
          // Server-side game error — surface to BLoC, do NOT reconnect
          _controller?.addError(error);
        } else {
          // Network error — trigger reconnect
          _scheduleReconnect();
        }
      },
      onDone: () {
        print('🔌 WS closed (onDone)');
        if (!_intentionalDisconnect) {
          _scheduleReconnect();
        }
      },
      cancelOnError: false,
    );
  }

  void _handleMessage(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'STATE_UPDATE') {
        final stateJson = json['state'] as Map<String, dynamic>;
        final state = GameState.fromJson(stateJson);
        _controller?.add(state);
      } else if (type == 'ERROR') {
        final reason = json['reason'] as String? ?? 'Unknown server error';
        _controller?.addError(ServerError(reason));
      }
    } catch (e, stack) {
      print('🚨 SocketRepository JSON Parse Error: $e\n$stack');
    }
  }

  void _closeSocket() {
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  Future<void> _scheduleReconnect() async {
    if (_intentionalDisconnect || _isReconnecting) return;
    if (_lastRoomId == null || _lastPlayerId == null || _lastSessionToken == null)
      return;

    _isReconnecting = true;
    _reconnectStatusController.add(ReconnectStatus.reconnecting);
    _closeSocket();

    int attempt = 0;
    while (!_intentionalDisconnect && attempt < _maxRetries) {
      final backoff = (_initialBackoffMs * (1 << attempt)).clamp(
        _initialBackoffMs,
        _maxBackoffMs,
      );
      print('🔄 Reconnect attempt ${attempt + 1}/$_maxRetries in ${backoff}ms…');
      await Future.delayed(Duration(milliseconds: backoff));

      if (_intentionalDisconnect) break;

      try {
        _openSocket(_lastRoomId!, _lastPlayerId!, _lastSessionToken!);
        // Give the socket a moment to establish
        await Future.delayed(const Duration(milliseconds: 500));
        if (_channel != null) {
          // Successfully re-opened — the onData handler will emit `reconnected`
          return;
        }
      } catch (_) {}

      attempt++;
    }

    // All retries exhausted
    if (!_intentionalDisconnect) {
      _isReconnecting = false;
      _reconnectStatusController.add(ReconnectStatus.failed);
      _controller?.addError(
        ServerError('Connection lost. Please rejoin the room.'),
      );
    }
  }
}

/// Emitted as a stream error when the server sends an ERROR message.
class ServerError implements Exception {
  final String reason;
  const ServerError(this.reason);

  @override
  String toString() => 'ServerError: $reason';
}
