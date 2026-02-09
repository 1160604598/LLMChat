class Conversation {
  final int id;
  final String title;
  final DateTime createdAt;
  final int? modelConfigId;

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    this.modelConfigId,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      title: json['title'],
      createdAt: DateTime.parse(json['created_at']),
      modelConfigId: json['model_config_id'],
    );
  }
}
