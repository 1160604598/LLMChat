class User {
  final int id;
  final String username;
  final String? modelBaseUrl;
  final String? modelApiKey;
  final String? modelName;
  final String? modelProvider;

  User({
    required this.id,
    required this.username,
    this.modelBaseUrl,
    this.modelApiKey,
    this.modelName,
    this.modelProvider,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      modelBaseUrl: json['model_base_url'],
      modelApiKey: json['model_api_key'],
      modelName: json['model_name'],
      modelProvider: json['model_provider'],
    );
  }
}
