import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class ApiService {
  static const String defaultBaseUrl = 'http://127.0.0.1:8000';
  static String baseUrl = defaultBaseUrl;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString('api_base_url') ?? defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    // Remove trailing slash if present
    baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    await prefs.setString('api_base_url', baseUrl);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
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

  Future<User> getCurrentUser() async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to get user');
    }
  }

  Future<User> updateConfig(String? baseUrlStr, String? apiKey, String? modelName) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/auth/config'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model_base_url': baseUrlStr,
        'model_api_key': apiKey,
        'model_name': modelName,
      }),
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update config');
    }
  }

  Future<List<Conversation>> getConversations() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/chat/conversations'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Conversation.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load conversations');
    }
  }

  Future<Conversation> createConversation(String title) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/chat/conversations'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'title': title}),
    );

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

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> messages = data['messages'];
      return messages.map((e) => Message.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load messages');
    }
  }

  Future<http.StreamedResponse> streamChat(String message, int? conversationId) async {
    final token = await getToken();
    final request = http.Request('POST', Uri.parse('$baseUrl/chat/stream'));
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'message': message,
      'conversation_id': conversationId,
    });

    return await request.send();
  }
}
