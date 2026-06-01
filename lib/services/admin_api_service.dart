import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';
import 'package:cross_file/cross_file.dart'; 

class AdminApiService {
  final _storage = const FlutterSecureStorage();

  Future<String?> _getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Token $token',
    };
  }

  // ========== КАТЕГОРИИ ==========
  Future<List<dynamic>> getCategories() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/admin/categories/'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['results'] ?? data;
    }
    throw Exception('Ошибка загрузки категорий');
  }

  Future<Map<String, dynamic>> createCategory(String name) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/admin/categories/'),
      headers: headers,
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Ошибка создания категории');
  }

  Future<Map<String, dynamic>> updateCategory(int id, String name) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}/api/admin/categories/$id/'),
      headers: headers,
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Ошибка обновления категории');
  }

  Future<void> deleteCategory(int id) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}/api/admin/categories/$id/'),
      headers: headers,
    );
    if (response.statusCode != 204) throw Exception('Ошибка удаления категории');
  }

  // ========== ТЕГИ ==========
  Future<List<dynamic>> getTags() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/admin/tags/'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['results'] ?? data;
    }
    throw Exception('Ошибка загрузки тегов');
  }

  Future<Map<String, dynamic>> createTag(String name) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/admin/tags/'),
      headers: headers,
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Ошибка создания тега');
  }

  Future<Map<String, dynamic>> updateTag(int id, String name) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}/api/admin/tags/$id/'),
      headers: headers,
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Ошибка обновления тега');
  }

  Future<void> deleteTag(int id) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}/api/admin/tags/$id/'),
      headers: headers,
    );
    if (response.statusCode != 204) throw Exception('Ошибка удаления тега');
  }

  // ========== ПОЛЬЗОВАТЕЛИ ==========
  Future<List<dynamic>> getUsers() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/admin/users/'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['results'] ?? data;
    }
    throw Exception('Ошибка загрузки пользователей');
  }

  Future<Map<String, dynamic>> updateUserRole(int userId, bool isStaff) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('${AppConfig.baseUrl}/api/admin/users/$userId/'),
      headers: headers,
      body: jsonEncode({'is_staff': isStaff}),
    );
    print('📡 Обновление роли: статус ${response.statusCode}, ответ: ${response.body}');
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Ошибка обновления роли: ${response.statusCode}');
  }

  // ========== СТАТЬИ ==========
  Future<List<dynamic>> getArticles({bool? isPublished}) async {
    final headers = await _getHeaders();
    String url = '${AppConfig.baseUrl}/api/admin/articles/';
    if (isPublished != null) url += '?is_published=$isPublished';
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['results'] ?? data;
    }
    throw Exception('Ошибка загрузки статей');
  }

  Future<Map<String, dynamic>> getArticle(int id) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/admin/articles/$id/'),
      headers: headers,
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Ошибка загрузки статьи');
  }

  Future<Map<String, dynamic>> createArticle(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/admin/articles/'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Ошибка создания статьи');
  }

  Future<Map<String, dynamic>> updateArticle(int id, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}/api/admin/articles/$id/'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Ошибка обновления статьи');
  }

  Future<void> deleteArticle(int id) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}/api/admin/articles/$id/'),
      headers: headers,
    );
    if (response.statusCode != 204) throw Exception('Ошибка удаления статьи');
  }

  Future<Map<String, dynamic>> togglePublish(int id, bool isPublished) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('${AppConfig.baseUrl}/api/admin/articles/$id/'),
      headers: headers,
      body: jsonEncode({'is_published': isPublished}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Ошибка изменения статуса');
  }

  // Загрузка изображения (работает на Web и мобильных)
  Future<Map<String, dynamic>> updateArticleImage(int articleId, XFile image) async {
    final token = await _getToken();
    if (token == null) throw Exception('Не авторизован');
    
    final request = http.MultipartRequest(
      'PATCH',
      Uri.parse('${AppConfig.baseUrl}/api/admin/articles/$articleId/'),
    );
    request.headers['Authorization'] = 'Token $token';
    
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
    throw Exception('Ошибка загрузки изображения: ${response.statusCode} - $responseBody');
  }

  // Удаление изображения
  Future<void> deleteArticleImage(int articleId) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('${AppConfig.baseUrl}/api/admin/articles/$articleId/'),
      headers: headers,
      body: jsonEncode({'image': null}),
    );
    if (response.statusCode != 200) {
      throw Exception('Ошибка удаления изображения');
    }
  }
}