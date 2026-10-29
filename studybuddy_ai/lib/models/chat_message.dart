enum MessageSender { user, ai }

class ChatMessage {
  final String id;
  final MessageSender sender;
  final String text;
  final DateTime timestamp;
  final String? noteReference;
  final List<String>? keyTakeaways;
  final bool outsideKnowledgeUsed;
  final String? conversationId;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.noteReference,
    this.keyTakeaways,
    this.outsideKnowledgeUsed = false,
    this.conversationId,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final senderStr = (json['sender'] as String? ?? 'user').toLowerCase();
    final sender = senderStr == 'ai' || senderStr == 'model' || senderStr == 'assistant'
        ? MessageSender.ai
        : MessageSender.user;

    DateTime parsedDate;
    if (json['created_at'] != null) {
      parsedDate = DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now();
    } else if (json['timestamp'] != null) {
      parsedDate = DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    final outsideRaw = json['outside_context'] ?? json['outside_knowledge_used'];
    final bool outsideUsed = outsideRaw == true ||
        outsideRaw == 'true' ||
        outsideRaw == 1 ||
        outsideRaw == '1';

    List<String>? takeaways;
    if (json['key_takeaways'] != null && json['key_takeaways'] is List) {
      takeaways = (json['key_takeaways'] as List)
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return ChatMessage(
      id: json['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      sender: sender,
      text: json['text']?.toString() ?? json['reply']?.toString() ?? '',
      timestamp: parsedDate,
      noteReference: json['note_reference']?.toString(),
      keyTakeaways: takeaways,
      outsideKnowledgeUsed: outsideUsed,
      conversationId: json['conversation_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender == MessageSender.user ? 'user' : 'ai',
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'note_reference': noteReference,
      'key_takeaways': keyTakeaways,
      'outside_knowledge_used': outsideKnowledgeUsed,
      'conversation_id': conversationId,
    };
  }
}

class ChatConversation {
  final String id;
  final String? documentId;
  final String title;
  final int messageCount;
  final String? lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  ChatConversation({
    required this.id,
    this.documentId,
    required this.title,
    this.messageCount = 0,
    this.lastMessage,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    List<ChatMessage> parsedMessages = [];
    if (json['messages'] != null && json['messages'] is List) {
      parsedMessages = (json['messages'] as List)
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();
    }

    return ChatConversation(
      id: json['id']?.toString() ?? '',
      documentId: json['document_id']?.toString(),
      title: json['title']?.toString() ?? 'Study Conversation',
      messageCount: json['message_count'] as int? ?? parsedMessages.length,
      lastMessage: json['last_message']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      messages: parsedMessages,
    );
  }

  ChatConversation copyWith({
    String? id,
    String? documentId,
    String? title,
    int? messageCount,
    String? lastMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      title: title ?? this.title,
      messageCount: messageCount ?? this.messageCount,
      lastMessage: lastMessage ?? this.lastMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }
}
