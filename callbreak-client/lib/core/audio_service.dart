import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static AudioPlayer? _player;
  static bool _isEnabled = true;

  static Source get _tingSource {
    return kIsWeb ? UrlSource('assets/sounds/ting.wav') : AssetSource('sounds/ting.wav');
  }

  static Source get _cardDealSequenceSource {
    return kIsWeb ? UrlSource('assets/sounds/card_deal_sequence.wav') : AssetSource('sounds/card_deal_sequence.wav');
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

  static AudioPlayer? _sequencePlayer;

  static Future<void> playCardDealSequence() async {
    if (!_isEnabled) return;
    
    try {
      _sequencePlayer ??= AudioPlayer();
      if (_sequencePlayer!.state == PlayerState.playing) {
        await _sequencePlayer!.stop();
      }
      await _sequencePlayer!.play(_cardDealSequenceSource);
    } catch (e) {
      print('AudioService: ERROR playing sequence: $e');
    }
  }

  static Future<void> preload() async {
    if (!_isEnabled) return;
    try {
      _player ??= AudioPlayer();
      await _player!.setSource(_tingSource);
      print('AudioService: preloaded ting.wav');

      _sequencePlayer ??= AudioPlayer();
      await _sequencePlayer!.setSource(_cardDealSequenceSource);
      print('AudioService: preloaded card_deal_sequence.wav');
    } catch (e) {
      print('AudioService: ERROR preloading sound: $e');
    }
  }

  static void toggleSound(bool enable) {
    _isEnabled = enable;
  }
}
