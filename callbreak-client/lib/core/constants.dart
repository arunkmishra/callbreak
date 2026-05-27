/// Server base URLs — update to your backend host/port.
const String kBackendHost = 'localhost';
const int kBackendPort = 8080;
const String kHttpBaseUrl = 'http://$kBackendHost:$kBackendPort';
const String kWsBaseUrl = 'ws://$kBackendHost:$kBackendPort';

/// Game constants
const int kTotalRounds = 5;
const int kPlayersRequired = 4;
const int kCardsPerHand = 13;
