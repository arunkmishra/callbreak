import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static AudioPlayer? _player;
  static bool _isEnabled = true;

  static Source get _tingSource {
    return kIsWeb ? UrlSource('assets/sounds/ting.wav') : AssetSource('sounds/ting.wav');
  }

  static Future<void> playTurnAlert() async {
    print('AudioService: playTurnAlert requested. isEnabled=$_isEnabled');
    if (!_isEnabled) return;
    try {
      _player ??= AudioPlayer();
      print('AudioService: player instantiated.');
      if (_player!.state == PlayerState.playing) {
        await _player!.stop();
      }
      print('AudioService: calling play() on ting.wav');
      await _player!.play(_tingSource);
      print('AudioService: play() completed');
    } catch (e) {
      print('AudioService: ERROR playing sound: $e');
    }
  }

  static Future<void> preload() async {
    if (!_isEnabled) return;
    try {
      _player ??= AudioPlayer();
      await _player!.setSource(_tingSource);
      print('AudioService: preloaded ting.wav');
    } catch (e) {
      print('AudioService: ERROR preloading sound: $e');
    }
  }

  static void toggleSound(bool enable) {
    _isEnabled = enable;
  }
}
