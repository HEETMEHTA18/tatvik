enum MessageRole { user, assistant }

class MentorMessage {
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final String? chatId;
  final Map<String, dynamic>? openclawTask;

  MentorMessage({
    required this.content,
    required this.role,
    required this.timestamp,
    this.chatId,
    this.openclawTask,
  });

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'role': role.name,
      'timestamp': timestamp.toIso8601String(),
      if (chatId != null) 'chatId': chatId,
    };
  }

  factory MentorMessage.fromJson(Map<String, dynamic> json) {
    return MentorMessage(
      content: json['content'] as String,
      role: MessageRole.values.byName(json['role'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      chatId: json['chatId'] as String?,
    );
  }
}
