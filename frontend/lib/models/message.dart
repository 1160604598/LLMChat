class Message {
  final int? id;
  final String role;
  final String content;
  final String? reasoningContent;
  final int? reasoningTimeMs;
  final int? conversationId;

  Message({
    this.id,
    required this.role,
    required this.content,
    this.reasoningContent,
    this.reasoningTimeMs,
    this.conversationId,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      role: json['role'],
      content: json['content'],
      reasoningContent: json['reasoning_content'],
      reasoningTimeMs: json['reasoning_time_ms'],
      conversationId: json['conversation_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
      'reasoning_content': reasoningContent,
      'reasoning_time_ms': reasoningTimeMs,
      'conversation_id': conversationId,
    };
  }
}
