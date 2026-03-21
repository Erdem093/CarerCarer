enum MessageRole { user, assistant }

class ConversationMessage {
  final MessageRole role;
  final String content;
  final DateTime timestamp;

  const ConversationMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      role: json['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role == MessageRole.user ? 'user' : 'assistant',
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  // For Claude API format
  Map<String, dynamic> toClaudeFormat() => {
        'role': role == MessageRole.user ? 'user' : 'assistant',
        'content': content,
      };
}
