import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

String get kHttpBaseUrl {
  if (kReleaseMode) return 'https://callbreak-1.onrender.com';
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080';
  }
  return 'http://localhost:8080';
}

String get kWsBaseUrl {
  if (kReleaseMode) return 'wss://callbreak-1.onrender.com';
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'ws://10.0.2.2:8080';
  }
  return 'ws://localhost:8080';
}

/// Game constants
const int kTotalRounds = 5;
const int kPlayersRequired = 4;
const int kCardsPerHand = 13;

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

String getUpdateMessage() {
  if (kIsWeb) {
    return 'A new mandatory update is available. Please refresh the page to update Callbreak and continue playing.';
  }
  if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
    return 'A new mandatory update is available. Please visit the App Store to update Callbreak and continue playing.';
  }
  return 'A new mandatory update is available. Please visit the Play Store to update Callbreak and continue playing.';
}
