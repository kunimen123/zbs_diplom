import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/article.dart';
import '../services/auth_service.dart';

class ArticlesProvider extends ChangeNotifier {
  List<Article> _articles = [];
  bool _loading = false;
 // String? _nextPageUrl; // для пагинации

  List<Article> get articles => _articles;
  bool get loading => _loading;

  // Загрузить список статей с учётом фильтров
  Future<void> fetchArticles({String? search, String? tag, bool? mine, AuthService? auth}) async {
    _loading = true;
    notifyListeners();

    String url = '${AppConfig.baseUrl}/api/articles/?';
    if (search != null && search.isNotEmpty) url += 'search=$search&';
    if (tag != null && tag.isNotEmpty) url += 'tag=$tag&';
    if (mine == true && auth != null && auth.isAuthenticated) {
      // используем специальный эндпоинт "my_articles"
      url = '${AppConfig.baseUrl}/api/articles/my_articles/';
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (auth != null && auth.isAuthenticated) {
      headers['Authorization'] = 'Token ${auth.token}';
    }

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['results'];
        _articles = results.map((json) => Article.fromJson(json)).toList();
        //_nextPageUrl = data['next']; // если есть пагинация DRF
      }
    } catch (e) {
      debugPrint('Ошибка загрузки статей: $e');
    }

    _loading = false;
    notifyListeners();
  }

  // Получить одну статью
  Future<Article?> fetchArticleDetail(int id, AuthService? auth) async {
    final headers = <String, String>{};
    if (auth != null && auth.isAuthenticated) {
      headers['Authorization'] = 'Token ${auth.token}';
    }
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/articles/$id/'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return Article.fromJson(jsonDecode(response.body));
    }
    return null;
  }

  // Добавить/убрать из избранного
  Future<bool> toggleFavorite(int articleId, AuthService auth) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/articles/$articleId/favorite/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token ${auth.token}',
      },
    );
    return response.statusCode == 200;
  }

  // Создание статьи (простая версия, без картинки)
  Future<Article?> createArticle(Map<String, dynamic> data, AuthService auth) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/articles/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token ${auth.token}',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) {
      return Article.fromJson(jsonDecode(response.body));
    }
    return null;
  }

  // Обновление статьи
  Future<Article?> updateArticle(int id, Map<String, dynamic> data, AuthService auth) async {
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}/api/articles/$id/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token ${auth.token}',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return Article.fromJson(jsonDecode(response.body));
    }
    return null;
  }
}