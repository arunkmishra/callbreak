import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/game_state.dart';

/// Reconnect status events surfaced to the BLoC.
enum ReconnectStatus { reconnecting, reconnected, failed }

/// Manages the WebSocket connection to the Callbreak server.
class SocketRepository {
  static const int APP_PROTOCOL_VERSION = 1;

  final String wsBaseUrl;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  StreamController<GameState>? _controller;
  final _reconnectStatusController = StreamController<ReconnectStatus>.broadcast();

  // ── Reconnect state ────────────────────────────────────────────────────────
  bool _intentionalDisconnect = false;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  
  String? _lastRoomId;
  String? _lastPlayerId;
  String? _lastSessionToken;

  static const _maxRetries = 9;
  static const _initialBackoffMs = 1000;
  static const _maxBackoffMs = 10000;

  SocketRepository({required this.wsBaseUrl});

  Stream<ReconnectStatus> get reconnectStatusStream => _reconnectStatusController.stream;

  // ── Public API ─────────────────────────────────────────────────────────────

  Stream<GameState> connect(String roomId, String playerId, String sessionToken) {
    _intentionalDisconnect = false;
    _reconnectAttempt = 0;
    _lastRoomId = roomId;
    _lastPlayerId = playerId;
    _lastSessionToken = sessionToken;

    _controller ??= StreamController<GameState>.broadcast();
    _openSocket();
    return _controller!.stream;
  }

  void sendAction(String actionType, [Map<String, dynamic>? payload]) {
    if (_channel == null) return;
    final message = <String, dynamic>{'type': actionType, ...?payload};
    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (_) {}
  }

  void disconnect() {
    _intentionalDisconnect = true;
    _cleanupSocket();
    _controller?.close();
    _controller = null;
    _lastRoomId = null;
    _lastPlayerId = null;
    _lastSessionToken = null;
  }

  bool get isConnected => _channel != null && _reconnectAttempt == 0;

  // ── Internal ───────────────────────────────────────────────────────────────

  void _openSocket() {
    _cleanupSocket(); // Close any stale channel and cancel listeners
    if (_intentionalDisconnect || _lastRoomId == null) return;

    final uri = Uri.parse(
        '$wsBaseUrl/ws/rooms/${_lastRoomId!.toUpperCase()}?playerId=$_lastPlayerId&sessionToken=$_lastSessionToken&protocol=$APP_PROTOCOL_VERSION');

    try {
      _channel = WebSocketChannel.connect(uri);
      
      // If ready completes successfully, we consider it connected (for UI purposes)
      _channel!.ready.then((_) {
        if (_reconnectAttempt > 0) {
          _reconnectStatusController.add(ReconnectStatus.reconnected);
        }
      }).catchError((_) {});

      _channelSub = _channel!.stream.listen(
        (dynamic raw) {
          // Got a message — we're definitely connected, reset retries
          if (_reconnectAttempt > 0) {
            _reconnectStatusController.add(ReconnectStatus.reconnected);
          }
          _reconnectAttempt = 0;
          _handleMessage(raw);
        },
        onError: (Object error) {
          print('🔌 WS stream error: $error');
          if (error is ServerError) {
            _controller?.addError(error);
          } else {
            _scheduleReconnect();
          }
        },
        onDone: () {
          print('🔌 WS closed (onDone) - Code: ${_channel?.closeCode}, Reason: ${_channel?.closeReason}');
          if (_channel?.closeReason == 'FORCE_UPDATE_REQUIRED') {
             _controller?.addError(const ServerError('FORCE_UPDATE_REQUIRED'));
             return;
          }
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      _scheduleReconnect();
    }
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

  void _cleanupSocket() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    // Canceling the subscription prevents onDone/onError from firing when we close the sink
    _channelSub?.cancel();
    _channelSub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect) return;
    _cleanupSocket();

    if (_reconnectAttempt >= _maxRetries) {
      _reconnectStatusController.add(ReconnectStatus.failed);
      _controller?.addError(ServerError('Connection lost. Please rejoin the room.'));
      return;
    }

    final backoff = (_initialBackoffMs * (1 << _reconnectAttempt)).clamp(
      _initialBackoffMs,
      _maxBackoffMs,
    );
    
    _reconnectAttempt++;
    _reconnectStatusController.add(ReconnectStatus.reconnecting);
    
    print('🔄 Reconnect attempt $_reconnectAttempt/$_maxRetries in ${backoff}ms…');
    
    _reconnectTimer = Timer(Duration(milliseconds: backoff), () {
      _openSocket();
    });
  }
}

/// Emitted as a stream error when the server sends an ERROR message.
class ServerError implements Exception {
  final String reason;
  const ServerError(this.reason);

  @override
  String toString() => 'ServerError: $reason';
}
