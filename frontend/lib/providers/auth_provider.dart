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

  Future<void> addModelConfig(ModelConfig config) async {
    try {
      await _apiService.addModelConfig(config);
      _user = await _apiService.getCurrentUser();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateModelConfig(ModelConfig config) async {
    try {
      await _apiService.updateModelConfig(config);
      _user = await _apiService.getCurrentUser();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteModelConfig(int id) async {
    try {
      await _apiService.deleteModelConfig(id);
      _user = await _apiService.getCurrentUser();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> reorderModelConfigs(List<ModelConfig> newOrder) async {
    // Optimistic update
    if (_user != null) {
      final oldConfigs = _user!.modelConfigs;
      // We can't modify the user object directly as fields are final.
      // But we can create a new User object or just rely on re-fetching.
      // For drag and drop, we need immediate feedback.
      // So we might update local state first.
      // However, User.modelConfigs is final list.
      // Let's just update the list in UI and call API.
      // The settings screen handles the list state.
    }
    
    try {
      await _apiService.reorderModelConfigs(newOrder);
      // Refresh user to get persisted order and any other updates
      _user = await _apiService.getCurrentUser();
      notifyListeners();
    } catch (e) {
      // Revert?
      rethrow;
    }
  }
}
