/// Represents an emoticon event received from the server.
class EmoticonEvent {
  final String playerId;
  final String emoticon;

  const EmoticonEvent({required this.playerId, required this.emoticon});
}
