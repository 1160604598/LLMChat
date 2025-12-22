class Conversation {
  final int id;
  final String title;
  final DateTime createdAt;

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      title: json['title'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
