import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';
import '../models/article.dart';

// Условный импорт для платформенных методов
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiService {
  final _storage = const FlutterSecureStorage();

  Future<String?> _getToken() async => await _storage.read(key: 'auth_token');

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

  // Получение статей с пагинацией
  Future<Map<String, dynamic>> getArticles({
    String? search,
    int? categoryId,
    int? tagId,
    bool? mine,
    String? nextUrl,
  }) async {
    final headers = await _getHeaders();
    Uri uri;
    if (nextUrl != null) {
      uri = Uri.parse(nextUrl);
    } else {
      uri = Uri.parse('${AppConfig.baseUrl}/api/articles/').replace(queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (categoryId != null) 'category': categoryId.toString(),
        if (tagId != null) 'tags': tagId.toString(),
        if (mine == true) 'mine': 'true',
      });
    }
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'articles': (data['results'] as List).map((j) => Article.fromJson(j)).toList(),
        'next': data['next'],
        'previous': data['previous'],
        'count': data['count'],
      };
    }
    throw Exception('Ошибка загрузки статей');
  }

  Future<Article> getArticle(int id) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/articles/$id/'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) return Article.fromJson(jsonDecode(response.body));
    throw Exception('Ошибка загрузки статьи');
  }

  Future<List<Map<String, dynamic>>> getTags() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/tags/'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data['results'] ?? data;
      return results.map<Map<String, dynamic>>((t) => {'id': t['id'], 'name': t['name']}).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/categories/'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data['results'] ?? data;
      return results.map<Map<String, dynamic>>((c) => {'id': c['id'], 'name': c['name']}).toList();
    }
    return [];
  }

  Future<void> toggleFavorite(int articleId) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/articles/$articleId/favorite/'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200) throw Exception('Ошибка при изменении избранного');
  }

  // Создание статьи (только для авторизованных)
  Future<Map<String, dynamic>> createArticle(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/articles/'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Ошибка создания статьи: ${response.body}');
  }

  // Обновление статьи (только для автора/редактора)
  Future<Map<String, dynamic>> updateArticle(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}/api/articles/$id/'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Ошибка обновления статьи: ${response.body}');
  }

  // Удаление статьи (только для автора/редактора/админа)
  Future<void> deleteArticle(int id) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}/api/articles/$id/'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 204) throw Exception('Ошибка удаления статьи');
  }

  // ==================== РАБОТА С ИЗОБРАЖЕНИЯМИ (поддержка Web) ====================
  
  // Загрузка изображения для статьи
  Future<Map<String, dynamic>> updateArticleImage(int articleId, dynamic image) async {
    final token = await _getToken();
    if (token == null) throw Exception('Необходима авторизация');
    
    if (kIsWeb) {
      // Для Web - отправляем через MultipartRequest (работает в Web)
      final uri = Uri.parse('${AppConfig.baseUrl}/api/articles/$articleId/');
      final request = http.MultipartRequest('PATCH', uri);
      request.headers['Authorization'] = 'Token $token';
      
      // В Web image - это XFile
      final bytes = await image.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: image.name,
      );
      request.files.add(multipartFile);
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        return jsonDecode(responseBody);
      }
      throw Exception('Ошибка загрузки изображения: ${response.statusCode}');
    } else {
      // Для мобильных платформ - используем File
      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse('${AppConfig.baseUrl}/api/articles/$articleId/'),
      );
      request.headers['Authorization'] = 'Token $token';
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        return jsonDecode(responseBody);
      }
      throw Exception('Ошибка загрузки изображения: ${response.statusCode}');
    }
  }

  // Удаление изображения статьи
  Future<void> deleteArticleImage(int articleId) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.baseUrl}/api/articles/$articleId/'),
      headers: await _getHeaders(),
      body: jsonEncode({'image': null}),
    );
    if (response.statusCode != 200) {
      throw Exception('Ошибка удаления изображения: ${response.statusCode}');
    }
  }
}