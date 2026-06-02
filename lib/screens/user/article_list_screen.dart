import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';
import '../../config.dart';
import 'article_detail_screen.dart';
import 'user_article_form_screen.dart';
import '../admin/article_form_screen.dart';

class ArticleListScreen extends StatefulWidget {
  const ArticleListScreen({super.key});

  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  final ScrollController _scrollController = ScrollController();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  List<dynamic> _articles = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMsg;
  String? _nextUrl;
  bool _hasMore = true;
  
  String _searchQuery = '';
  int? _selectedTagId;
  bool _showMyArticles = false;
  bool _showFavorites = false;
  List<dynamic> _tags = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && !_isLoading) {
        _loadMore();
      }
    }
  }

  Future<String?> _getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Token $token';
    }
    return headers;
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMsg = null;
        _articles = [];
        _nextUrl = null;
        _hasMore = true;
      });
    }
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final headers = await _getHeaders();
    
    try {
      String url;
      if (_showFavorites && authService.isAuthenticated) {
        url = '${AppConfig.baseUrl}/api/articles/favorites/';
      } else if (_showMyArticles && authService.isAuthenticated) {
        url = '${AppConfig.baseUrl}/api/articles/my_articles/';
      } else {
        url = '${AppConfig.baseUrl}/api/articles/';
      }
      
      final params = <String>[];
      if (_searchQuery.isNotEmpty) params.add('search=$_searchQuery');
      if (_selectedTagId != null) params.add('tags=$_selectedTagId');
      if (params.isNotEmpty) url += '?${params.join('&')}';
      
      final articlesResponse = await http.get(Uri.parse(url), headers: headers);
      final tagsResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/tags/'),
        headers: headers,
      );
      
      if (articlesResponse.statusCode == 200 && tagsResponse.statusCode == 200) {
        final articlesData = jsonDecode(articlesResponse.body);
        final tagsData = jsonDecode(tagsResponse.body);
        
        if (mounted) {
          setState(() {
            _articles = articlesData['results'] ?? [];
            _nextUrl = articlesData['next'];
            _hasMore = articlesData['next'] != null;
            _tags = tagsData['results'] ?? tagsData;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Ошибка загрузки: ${articlesResponse.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_nextUrl == null || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    final headers = await _getHeaders();
    try {
      final response = await http.get(Uri.parse(_nextUrl!), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _articles.addAll(data['results'] ?? []);
            _nextUrl = data['next'];
            _hasMore = data['next'] != null;
            _isLoadingMore = false;
          });
        }
      } else {
        throw Exception();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _toggleFavorite(int articleId, bool isFavorited) async {
    final token = await _getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите, чтобы добавлять в избранное'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    final headers = await _getHeaders();
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/articles/$articleId/favorite/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        // Обновляем локальное состояние
        setState(() {
          final index = _articles.indexWhere((a) => a['id'] == articleId);
          if (index != -1) {
            _articles[index]['is_favorited'] = !isFavorited;
            if (!isFavorited) {
              _articles[index]['favorites_count'] = (_articles[index]['favorites_count'] ?? 0) + 1;
            } else {
              _articles[index]['favorites_count'] = (_articles[index]['favorites_count'] ?? 0) - 1;
            }
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFavorited ? 'Удалено из избранного' : 'Добавлено в избранное'),
            backgroundColor: isFavorited ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка'), backgroundColor: Colors.red),
      );
    }
  }

  void _onSearch(String query) {
    _searchQuery = query;
    _loadData();
  }

  void _onTagFilter(int? tagId) {
    _selectedTagId = tagId;
    _loadData();
  }

  void _toggleMyArticles() {
    setState(() {
      _showMyArticles = true;
      _showFavorites = false;
    });
    _loadData();
  }

  void _toggleFavorites() {
    setState(() {
      _showFavorites = true;
      _showMyArticles = false;
    });
    _loadData();
  }

  void _clearFilters() {
    setState(() {
      _showMyArticles = false;
      _showFavorites = false;
      _searchQuery = '';
      _selectedTagId = null;
    });
    _loadData();
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
    final authService = Provider.of<AuthService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('База Знаний'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.logout();
              if (mounted) Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.deepPurple,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'Поиск статей...',
                  prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchQuery = '';
                            _loadData();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.deepPurple.shade50,
            child: Row(
              children: [
                if (authService.isAuthenticated)
                  FilterChip(
                    label: const Text('Мои статьи'),
                    selected: _showMyArticles,
                    onSelected: (_) => _toggleMyArticles(),
                    backgroundColor: Colors.white,
                    selectedColor: Colors.deepPurple.shade100,
                    checkmarkColor: Colors.deepPurple,
                  ),
                if (authService.isAuthenticated)
                  const SizedBox(width: 8),
                if (authService.isAuthenticated)
                  FilterChip(
                    label: const Text('Избранное'),
                    selected: _showFavorites,
                    onSelected: (_) => _toggleFavorites(),
                    backgroundColor: Colors.white,
                    selectedColor: Colors.red.shade100,
                    checkmarkColor: Colors.red,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        isExpanded: true,
                        value: _selectedTagId,
                        hint: const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Text('Все теги'),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Padding(
                              padding: EdgeInsets.only(left: 12),
                              child: Text('Все теги'),
                            ),
                          ),
                          ..._tags.map((tag) => DropdownMenuItem<int?>(
                            value: tag['id'],
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Text(tag['name']),
                            ),
                          )),
                        ],
                        onChanged: _onTagFilter,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
                ),
                if (_showMyArticles || _showFavorites || _searchQuery.isNotEmpty || _selectedTagId != null)
                  IconButton(
                    icon: const Icon(Icons.clear_all, color: Colors.deepPurple),
                    onPressed: _clearFilters,
                    tooltip: 'Сбросить фильтры',
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMsg != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                            const SizedBox(height: 16),
                            Text(_errorMsg!),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _loadData, child: const Text('Повторить')),
                          ],
                        ),
                      )
                    : _articles.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_showFavorites)
                                  const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                                if (_showMyArticles)
                                  const Icon(Icons.article_outlined, size: 64, color: Colors.grey),
                                if (!_showMyArticles && !_showFavorites)
                                  const Icon(Icons.article_outlined, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  _showFavorites
                                      ? 'Нет избранных статей'
                                      : _showMyArticles
                                          ? 'У вас нет статей'
                                          : 'Нет статей',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(12),
                            itemCount: _articles.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _articles.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                );
                              }
                              final article = _articles[index];
                              final tagNames = (article['tags_detail'] as List<dynamic>?)
                                  ?.map((t) => t['name'] as String)
                                  .toList() ?? [];
                              final isFavorited = article['is_favorited'] ?? false;
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => ArticleDetailScreen(articleId: article['id'])),
                                    ).then((_) => _loadData());
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(article['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        if ((article['summary'] ?? '').isNotEmpty)
                                          Text(article['summary'], maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                                            const SizedBox(width: 4),
                                            Expanded(child: Text(article['author_detail']?['username'] ?? 'Автор', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
                                            const SizedBox(width: 12),
                                            GestureDetector(
                                              onTap: () => _toggleFavorite(article['id'], isFavorited),
                                              child: Icon(
                                                isFavorited ? Icons.favorite : Icons.favorite_border,
                                                size: 14,
                                                color: isFavorited ? Colors.red : Colors.grey.shade500,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text('${article['favorites_count'] ?? 0}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                            const SizedBox(width: 12),
                                            Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                                            const SizedBox(width: 4),
                                            Text(_formatDate(article['created_at']), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                          ],
                                        ),
                                        if (tagNames.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Wrap(
                                              spacing: 6,
                                              children: tagNames.take(3).map((tag) => Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.deepPurple.shade50,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(tag, style: TextStyle(fontSize: 10, color: Colors.deepPurple.shade700)),
                                              )).toList(),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: authService.isAuthenticated
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => authService.isStaff
                        ? const ArticleFormScreen()
                        : const UserArticleFormScreen(),
                  ),
                );
                if (result == true) _loadData();
              },
              backgroundColor: Colors.deepPurple,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}