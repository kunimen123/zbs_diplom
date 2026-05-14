import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class AuthService with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  String? _token;
  String? _username;
  bool _isStaff = false;

  String? get token => _token;
  bool get isAuthenticated => _token != null;
  bool get isStaff => _isStaff;
  String? get username => _username;

  Future<void> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api-token-auth/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['token'];
      _username = username;
      
      // ПРОСТО СОХРАНЯЕМ - если username "admin", значит админ
      // Либо проверяем по硬коду
      if (username == 'admin' || username == 'administrator') {
        _isStaff = true;
      } else {
        _isStaff = false;
      }
      
      await _storage.write(key: 'auth_token', value: _token);
      await _storage.write(key: 'username', value: _username);
      await _storage.write(key: 'is_staff', value: _isStaff.toString());
      
      notifyListeners();
    } else {
      throw Exception('Неверные учетные данные');
    }
  }

  Future<void> register(String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      _token = data['token'];
      _username = data['username'];
      _isStaff = false;
      
      await _storage.write(key: 'auth_token', value: _token);
      await _storage.write(key: 'username', value: _username);
      await _storage.write(key: 'is_staff', value: 'false');
      
      notifyListeners();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Ошибка регистрации');
    }
  }

  Future<void> logout() async {
    _token = null;
    _username = null;
    _isStaff = false;
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'username');
    await _storage.delete(key: 'is_staff');
    notifyListeners();
  }

  Future<void> tryAutoLogin() async {
    final storedToken = await _storage.read(key: 'auth_token');
    final storedUsername = await _storage.read(key: 'username');
    final storedIsStaff = await _storage.read(key: 'is_staff');
    
    if (storedToken != null && storedUsername != null) {
      _token = storedToken;
      _username = storedUsername;
      _isStaff = storedIsStaff == 'true';
      notifyListeners();
    }
  }
}