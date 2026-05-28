import 'package:flutter/foundation.dart';

const String kHttpBaseUrl = kReleaseMode ? 'https://callbreak-1.onrender.com' : 'http://localhost:8080';
const String kWsBaseUrl = kReleaseMode ? 'wss://callbreak-1.onrender.com' : 'ws://localhost:8080';

/// Game constants
const int kTotalRounds = 5;
const int kPlayersRequired = 4;
const int kCardsPerHand = 13;
