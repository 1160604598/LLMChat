import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  Future<void> checkAuth() async {
    final token = await _apiService.getToken();
    if (token != null) {
      try {
        _user = await _apiService.getCurrentUser();
        notifyListeners();
      } catch (e) {
        await _apiService.logout();
      }
    }
  }

  Future<void> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiService.login(username, password);
      _user = await _apiService.getCurrentUser();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String username, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiService.register(username, password);
      // Auto login after register? Or just return
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _apiService.logout();
    _user = null;
    notifyListeners();
  }

  Future<void> updateConfig(String? baseUrl, String? apiKey, String? modelName) async {
    try {
      _user = await _apiService.updateConfig(baseUrl, apiKey, modelName);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}
