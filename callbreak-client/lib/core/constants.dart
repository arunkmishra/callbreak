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
