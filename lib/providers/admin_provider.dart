import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/article.dart';
import '../services/auth_service.dart';

class AdminProvider extends ChangeNotifier {
  List<Article> _articles = [];
  bool _loading = false;

  List<Article> get articles => _articles;
  bool get loading => _loading;

  Future<void> fetchAdminArticles(AuthService auth) async {
    _loading = true;
    notifyListeners();
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/admin/articles/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token ${auth.token}',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List results = data['results'];
      _articles = results.map((json) => Article.fromJson(json)).toList();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> deleteArticle(int id, AuthService auth) async {
    await http.delete(
      Uri.parse('${AppConfig.baseUrl}/api/admin/articles/$id/'),
      headers: {'Authorization': 'Token ${auth.token}'},
    );
    // обновим список
    await fetchAdminArticles(auth);
  }

  // Можно добавить методы для категорий, тегов, пользователей точно так же
}