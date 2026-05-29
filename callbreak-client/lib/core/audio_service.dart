import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static AudioPlayer? _player;
  static bool _isEnabled = true;
  static AudioPlayer? _sequencePlayer;

  static Uint8List? _tingBytes;
  static Uint8List? _sequenceBytes;

  static Future<void> playTurnAlert() async {
    if (!_isEnabled) return;
    try {
      _player ??= AudioPlayer();
      if (_player!.state == PlayerState.playing) {
        await _player!.stop();
      }
      if (kIsWeb && _tingBytes != null) {
        await _player!.play(BytesSource(_tingBytes!));
      } else if (!kIsWeb) {
        await _player!.play(AssetSource('sounds/ting.wav'));
      }
    } catch (e) {
      print('AudioService: ERROR playing sound: $e');
    }
  }

  static Future<void> playCardDealSequence() async {
    if (!_isEnabled) return;
    try {
      _sequencePlayer ??= AudioPlayer();
      if (_sequencePlayer!.state == PlayerState.playing) {
        await _sequencePlayer!.stop();
      }
      if (kIsWeb && _sequenceBytes != null) {
        await _sequencePlayer!.play(BytesSource(_sequenceBytes!));
      } else if (!kIsWeb) {
        await _sequencePlayer!.play(AssetSource('sounds/card_deal_sequence.wav'));
      }
    } catch (e) {
      print('AudioService: ERROR playing sequence: $e');
    }
  }

  static Future<void> preload() async {
    if (!_isEnabled) return;
    try {
      // Force Android/iOS to treat this as a Game audio source (plays over media volume)
      if (!kIsWeb) {
        await AudioPlayer.global.setAudioContext(AudioContextConfig(
          respectSilence: false,
          stayAwake: false,
        ).build());
      }

      _player ??= AudioPlayer();
      _sequencePlayer ??= AudioPlayer();

      if (kIsWeb) {
        final tingData = await rootBundle.load('assets/sounds/ting.wav');
        _tingBytes = tingData.buffer.asUint8List();
        await _player!.setSource(BytesSource(_tingBytes!));

        final seqData = await rootBundle.load('assets/sounds/card_deal_sequence.wav');
        _sequenceBytes = seqData.buffer.asUint8List();
        await _sequencePlayer!.setSource(BytesSource(_sequenceBytes!));
      } else {
        await _player!.setSource(AssetSource('sounds/ting.wav'));
        await _sequencePlayer!.setSource(AssetSource('sounds/card_deal_sequence.wav'));
      }
      print('AudioService: preloaded ting.wav and card_deal_sequence.wav');
    } catch (e) {
      print('AudioService: ERROR preloading sound: $e');
    }
  }

  static void toggleSound(bool enable) {
    _isEnabled = enable;
  }
}
