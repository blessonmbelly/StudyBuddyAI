enum MessageSender { user, ai }

class ChatMessage {
  final String id;
  final MessageSender sender;
  final String text;
  final DateTime timestamp;
  final String? noteReference;
  final List<String>? keyTakeaways;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.noteReference,
    this.keyTakeaways,
  });
}
