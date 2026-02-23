import 'package:flutter/material.dart';

import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  AuthProvider() {
    _bootstrap();
  }

  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _isBootstrapping = true;
  String? _error;
  Map<String, dynamic>? _user;
  String? _driverId;

  bool get isLoading => _isLoading;
  bool get isBootstrapping => _isBootstrapping;
  String? get error => _error;
  Map<String, dynamic>? get user => _user;
  String? get driverId => _driverId;

  bool get isAuthenticated => _user != null && (_driverId?.isNotEmpty ?? false);

  String get displayName {
    final name = user?['name']?.toString();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'Driver';
  }

  Future<void> _bootstrap() async {
    _isBootstrapping = true;
    notifyListeners();

    _user = await _apiService.getUser();
    _driverId = await _apiService.getDriverId();

    _isBootstrapping = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _apiService.login(email, password);

    _isLoading = false;
    if (result['success'] == true) {
      _user = result['user'] as Map<String, dynamic>?;
      _driverId = result['driverId']?.toString();
      notifyListeners();
      return true;
    }

    _error = result['message']?.toString() ?? 'Unable to login.';
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await _apiService.logout();
    _user = null;
    _driverId = null;
    _error = null;
    notifyListeners();
  }
}
