enum ChatMessageType { text, poke, reaction }

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final ChatMessageType type;
  final Map<String, dynamic>? metadata;
  final DateTime? readAt;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.type = ChatMessageType.text,
    this.metadata,
    this.readAt,
    required this.createdAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'] as String,
        senderId: map['sender_id'] as String,
        receiverId: map['receiver_id'] as String,
        content: map['content'] as String,
        type: ChatMessageType.values.firstWhere(
          (t) => t.name == (map['type'] as String? ?? 'text'),
          orElse: () => ChatMessageType.text,
        ),
        metadata: map['metadata'] != null
            ? Map<String, dynamic>.from(map['metadata'] as Map)
            : null,
        readAt: map['read_at'] != null
            ? DateTime.tryParse(map['read_at'] as String)
            : null,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );

  bool get isRead => readAt != null;

  String get previewText => switch (type) {
        ChatMessageType.poke => '👋 Cutucada!',
        ChatMessageType.reaction =>
          '${metadata?['emoji'] ?? '❤️'} Reagiu ao seu status',
        ChatMessageType.text => content,
      };
}
