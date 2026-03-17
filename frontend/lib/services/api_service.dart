import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class ApiService {
  static const String defaultBaseUrl = 'http://127.0.0.1:8000';
  static String baseUrl = defaultBaseUrl;
  static Function()? onTokenExpired;
  static const _storage = FlutterSecureStorage();

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('version.json'));
        if (response.statusCode == 200) {
          final Map<String, dynamic> versionData = jsonDecode(response.body);
          final String? serverUrl = versionData['default_server_url'];
          if (serverUrl != null && serverUrl.isNotEmpty) {
            baseUrl = prefs.getString('api_base_url') ?? serverUrl;
            return;
          }
        }
      } catch (e) {
        print('Failed to load version.json: $e');
      }
    }
    
    baseUrl = prefs.getString('api_base_url') ?? defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    // Remove trailing slash if present
    baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    await prefs.setString('api_base_url', baseUrl);
  }

  Future<String?> getToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('access_token');
    }
    return await _storage.read(key: 'access_token');
  }

  Future<void> setToken(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
      return;
    }
    await _storage.write(key: 'access_token', value: token);
  }

  Future<void> logout() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      return;
    }
    await _storage.delete(key: 'access_token');
  }

  Future<User> register(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to register: ${response.body}');
    }
  }

  Future<String> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': username, 'password': password},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['access_token'];
      await setToken(token);
      return token;
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }

  Future<void> reorderModelConfigs(List<ModelConfig> configs) async {
    final token = await getToken();
    final List<Map<String, dynamic>> orders = configs.asMap().entries.map((entry) {
      return {
        'id': entry.value.id,
        'display_order': entry.key,
      };
    }).toList();

    final response = await http.put(
      Uri.parse('$baseUrl/auth/models/reorder'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(orders),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to reorder models: ${response.body}');
    }
  }

  Future<User> getCurrentUser() async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 401) {
      onTokenExpired?.call();
    }

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to get user');
    }
  }

  Future<ModelConfig> addModelConfig(ModelConfig config) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/models'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(config.toJson()),
    );

    if (response.statusCode == 200) {
      return ModelConfig.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to add model config: ${response.body}');
    }
  }

  Future<ModelConfig> updateModelConfig(ModelConfig config) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/auth/models/${config.id}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(config.toJson()),
    );

    if (response.statusCode == 200) {
      return ModelConfig.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update model config: ${response.body}');
    }
  }

  Future<void> deleteModelConfig(int id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/auth/models/$id'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete model config: ${response.body}');
    }
  }

  Future<List<Conversation>> getConversations() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/chat/conversations'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 401) {
      onTokenExpired?.call();
    }

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Conversation.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load conversations');
    }
  }

  Future<Conversation> createConversation(String title, {int? modelConfigId}) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/chat/conversations'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': title,
        'model_config_id': modelConfigId,
      }),
    );

    if (response.statusCode == 401) {
      onTokenExpired?.call();
    }

    if (response.statusCode == 200) {
      return Conversation.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create conversation');
    }
  }

  Future<void> deleteConversation(int conversationId) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/chat/conversations/$conversationId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 401) {
      onTokenExpired?.call();
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to delete conversation');
    }
  }

  Future<List<Message>> getMessages(int conversationId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/chat/conversations/$conversationId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 401) {
      onTokenExpired?.call();
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> messages = data['messages'];
      return messages.map((e) => Message.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load messages');
    }
  }

  Future<http.StreamedResponse> streamChat(String message, int? conversationId, [ModelConfig? config]) async {
    final token = await getToken();
    final request = http.Request('POST', Uri.parse('$baseUrl/chat/stream'));
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Content-Type'] = 'application/json';
    
    final Map<String, dynamic> body = {
      'message': message,
      'conversation_id': conversationId,
    };

    if (config != null) {
      body['model_config'] = {
        'model_base_url': config.baseUrl,
        'model_api_key': config.apiKey,
        'model_name': config.modelName,
        'model_provider': config.provider,
      };
    }

    request.body = jsonEncode(body);

    final response = await request.send();
    if (response.statusCode == 401) {
      onTokenExpired?.call();
      throw Exception('Unauthorized');
    }
    return response;
  }
}
