class Message {
  final int? id;
  final String role;
  final String content;
  final int? conversationId;

  Message({
    this.id,
    required this.role,
    required this.content,
    this.conversationId,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      role: json['role'],
      content: json['content'],
      conversationId: json['conversation_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
      'conversation_id': conversationId,
    };
  }
}
