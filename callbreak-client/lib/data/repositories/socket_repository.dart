import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/game_state.dart';

/// Manages the WebSocket connection to the Callbreak server.
///
/// Architecture:
/// - [connect] opens the socket and exposes a [Stream<GameState>].
/// - [sendAction] sends a typed action to the server.
/// - [disconnect] closes the connection cleanly.
///
/// The BLoC layer listens to [stateStream] and dispatches [ServerStateUpdated]
/// events. It NEVER mutates local state from a UI interaction — it always
/// waits for the server broadcast.
class SocketRepository {
  final String wsBaseUrl;

  WebSocketChannel? _channel;
  StreamController<GameState>? _controller;

  SocketRepository({required this.wsBaseUrl});

  /// Connects to the room and returns a [Stream<GameState>] of server updates.
  ///
  /// URL: ws://<host>/ws/rooms/{roomId}?playerId={playerId}
  Stream<GameState> connect(String roomId, String playerId, String sessionToken) {
    disconnect(); // close any existing connection

    _controller = StreamController<GameState>.broadcast();

    _channel = WebSocketChannel.connect(
      Uri.parse('$wsBaseUrl/ws/rooms/${roomId.toUpperCase()}?playerId=$playerId&sessionToken=$sessionToken'),
    );

    _channel!.stream.listen(
      (dynamic raw) {
        try {
          final json = jsonDecode(raw as String) as Map<String, dynamic>;
          final type = json['type'] as String?;

          if (type == 'STATE_UPDATE') {
            final stateJson = json['state'] as Map<String, dynamic>;
            final state = GameState.fromJson(stateJson);
            _controller?.add(state);
          }
          // ERROR messages are surfaced as stream errors for the BLoC to handle
          else if (type == 'ERROR') {
            final reason = json['reason'] as String? ?? 'Unknown server error';
            _controller?.addError(ServerError(reason));
          }
        } catch (e) {
          _controller?.addError(e);
        }
      },
      onError: (Object error) => _controller?.addError(error),
      onDone: () => _controller?.close(),
    );

    return _controller!.stream;
  }

  /// Sends a typed action to the server.
  ///
  /// [actionType] is the message discriminator, e.g. "START_GAME", "PLAY_CARD".
  /// [payload] is a map of additional fields merged into the JSON.
  void sendAction(String actionType, [Map<String, dynamic>? payload]) {
    if (_channel == null) return;
    final message = <String, dynamic>{'type': actionType, ...?payload};
    _channel!.sink.add(jsonEncode(message));
  }

  /// Closes the WebSocket connection and cleans up resources.
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _controller?.close();
    _controller = null;
  }

  bool get isConnected => _channel != null;
}

/// Emitted as a stream error when the server sends an ERROR message.
class ServerError implements Exception {
  final String reason;
  const ServerError(this.reason);

  @override
  String toString() => 'ServerError: $reason';
}
