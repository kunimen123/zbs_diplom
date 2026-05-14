import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config.dart';
import '../admin/article_form_screen.dart';
import 'user_article_form_screen.dart';

class ArticleDetailScreen extends StatefulWidget {
  final int articleId;
  const ArticleDetailScreen({super.key, required this.articleId});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  Map<String, dynamic>? _article;
  List<dynamic> _recommendations = [];
  bool _isLoading = true;
  bool _isFavorite = false;
  String? _error;
  bool _canEdit = false;
  bool _isStaff = false;
  int? _currentUserId;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<String?> _getToken() async => await _storage.read(key: 'auth_token');

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

  String _getFullImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    if (imagePath.startsWith('http')) return imagePath;
    // Убираем возможный дубль /media
    String cleanPath = imagePath;
    if (cleanPath.startsWith('/media/')) {
      cleanPath = cleanPath.substring(6);
    }
    return '${AppConfig.baseUrl}/media/$cleanPath';
  }

  Future<void> _loadData() async {
    try {
      final headers = await _getHeaders();
      final articleRes = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/articles/${widget.articleId}/'),
        headers: headers,
      );
      if (articleRes.statusCode != 200) throw Exception('Не удалось загрузить статью');
      final article = jsonDecode(articleRes.body);
      
      // Рекомендации по первому тегу
      List<dynamic> recommendations = [];
      final tags = (article['tags_detail'] as List?) ?? [];
      if (tags.isNotEmpty) {
        final tagId = tags.first['id'];
        final recRes = await http.get(
          Uri.parse('${AppConfig.baseUrl}/api/articles/?tags=$tagId'),
          headers: headers,
        );
        if (recRes.statusCode == 200) {
          final recData = jsonDecode(recRes.body);
          recommendations = (recData['results'] as List)
              .where((a) => a['id'] != widget.articleId)
              .take(5)
              .toList();
        }
      }
      
      // Проверка прав на редактирование
      bool canEdit = false;
      bool isStaff = false;
      final token = await _getToken();
      if (token != null) {
        final profileRes = await http.get(
          Uri.parse('${AppConfig.baseUrl}/api/profile/'),
          headers: headers,
        );
        if (profileRes.statusCode == 200) {
          final profile = jsonDecode(profileRes.body);
          _currentUserId = profile['id'];
          isStaff = profile['is_staff'] ?? false;
          canEdit = isStaff ||
              article['author'] == _currentUserId ||
              (article['editors'] as List?)?.contains(_currentUserId) == true;
        }
      }

      if (mounted) {
        setState(() {
          _article = article;
          _recommendations = recommendations;
          _isFavorite = article['is_favorited'] ?? false;
          _isLoading = false;
          _canEdit = canEdit;
          _isStaff = isStaff;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final token = await _getToken();
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Войдите, чтобы добавлять в избранное'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    try {
      final headers = await _getHeaders();
      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/articles/${widget.articleId}/favorite/'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() => _isFavorite = !_isFavorite);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_isFavorite ? 'Добавлено в избранное' : 'Удалено из избранного')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при изменении избранного'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteArticle() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Удалить статью?'),
        content: const Text('Действие необратимо.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final res = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/api/articles/${widget.articleId}/'),
        headers: await _getHeaders(),
      );
      if (res.statusCode != 204) throw Exception();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Статья удалена')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка удаления'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _editArticle() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _isStaff
            ? ArticleFormScreen(articleId: widget.articleId)
            : UserArticleFormScreen(articleId: widget.articleId),
      ),
    );
    if (result == true && mounted) _loadData();
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays > 7) return '${date.day}.${date.month}.${date.year}';
      if (diff.inDays > 0) return '${diff.inDays} дн. назад';
      if (diff.inHours > 0) return '${diff.inHours} ч. назад';
      return 'только что';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = _article?['image'] != null && _article!['image'].toString().isNotEmpty
        ? _getFullImageUrl(_article!['image'].toString())
        : null;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text('Ошибка: $_error', style: TextStyle(color: Colors.red.shade700)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: imageUrl != null ? 300 : 200,
                      pinned: true,
                      backgroundColor: Colors.deepPurple.shade900,
                      foregroundColor: Colors.white,
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text(
                          _article!['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        background: imageUrl != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [Colors.deepPurple.shade800, Colors.indigo.shade700],
                                          ),
                                        ),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                : null,
                                            color: Colors.white,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [Colors.deepPurple.shade800, Colors.indigo.shade700],
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(Icons.broken_image, size: 60, color: Colors.white.withAlpha(100)),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withAlpha(180),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Colors.deepPurple.shade800, Colors.indigo.shade700],
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.code,
                                    size: 80,
                                    color: Colors.white.withAlpha(50),
                                  ),
                                ),
                              ),
                      ),
                      actions: [
                        if (_canEdit)
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: _editArticle,
                            tooltip: 'Редактировать',
                          ),
                        if (_canEdit)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.white),
                            onPressed: _deleteArticle,
                            tooltip: 'Удалить',
                          ),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Информация об авторе и дате
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.person, size: 18, color: Colors.deepPurple.shade700),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _article!['author_detail']?['username'] ?? 'Автор',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      Text(
                                        _formatDate(_article!['created_at']),
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                ),
                                // Кнопка избранного
                                Container(
                                  decoration: BoxDecoration(
                                    color: _isFavorite ? Colors.red.shade50 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                                      color: _isFavorite ? Colors.red : Colors.grey.shade600,
                                      size: 22,
                                    ),
                                    onPressed: _toggleFavorite,
                                    tooltip: _isFavorite ? 'Удалить из избранного' : 'В избранное',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Категория
                            if (_article!['category_detail'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.folder_outlined, size: 14, color: Colors.deepPurple.shade700),
                                    const SizedBox(width: 6),
                                    Text(
                                      _article!['category_detail']['name'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.deepPurple.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                            // Теги
                            if ((_article!['tags_detail'] as List).isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: (_article!['tags_detail'] as List).map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    tag['name'],
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                  ),
                                )).toList(),
                              ),
                            const SizedBox(height: 24),
                            // Содержание статьи
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.shade200,
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                _article!['content'] ?? '',
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.6,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Рекомендации
                            if (_recommendations.isNotEmpty) ...[
                              const Text(
                                'Рекомендуемые статьи',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 160,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _recommendations.length,
                                  itemBuilder: (ctx, i) {
                                    final rec = _recommendations[i];
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(builder: (_) => ArticleDetailScreen(articleId: rec['id'])),
                                        );
                                      },
                                      child: Container(
                                        width: 220,
                                        margin: const EdgeInsets.only(right: 12),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.grey.shade200,
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.article, size: 32, color: Colors.deepPurple.shade300),
                                            const SizedBox(height: 8),
                                            Text(
                                              rec['title'],
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              rec['author_detail']?['username'] ?? 'Автор',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}