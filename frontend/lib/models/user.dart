class ModelConfig {
  final int? id;
  final String name;
  final String baseUrl;
  final String? apiKey;
  final String modelName;
  final String provider;
  final int displayOrder;

  ModelConfig({
    this.id,
    required this.name,
    required this.baseUrl,
    this.apiKey,
    required this.modelName,
    required this.provider,
    this.displayOrder = 0,
  });

  factory ModelConfig.fromJson(Map<String, dynamic> json) {
    return ModelConfig(
      id: json['id'],
      name: json['name'],
      baseUrl: json['base_url'],
      apiKey: json['api_key'],
      modelName: json['model_name'],
      provider: json['provider'],
      displayOrder: json['display_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'base_url': baseUrl,
      'api_key': apiKey,
      'model_name': modelName,
      'provider': provider,
      'display_order': displayOrder,
    };
  }
}

class User {
  final int id;
  final String username;
  final String? modelBaseUrl;
  final String? modelApiKey;
  final String? modelName;
  final String? modelProvider;
  final List<ModelConfig> modelConfigs;

  User({
    required this.id,
    required this.username,
    this.modelBaseUrl,
    this.modelApiKey,
    this.modelName,
    this.modelProvider,
    this.modelConfigs = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      modelBaseUrl: json['model_base_url'],
      modelApiKey: json['model_api_key'],
      modelName: json['model_name'],
      modelProvider: json['model_provider'],
      modelConfigs: (json['model_configs'] as List<dynamic>?)
              ?.map((e) => ModelConfig.fromJson(e))
              .toList() ??
          [],
    );
  }
}
