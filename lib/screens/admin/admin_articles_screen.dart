import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';
import 'article_form_screen.dart';

class AdminArticlesScreen extends StatefulWidget {
  const AdminArticlesScreen({super.key});

  @override
  State<AdminArticlesScreen> createState() => _AdminArticlesScreenState();
}

class _AdminArticlesScreenState extends State<AdminArticlesScreen> {
  final AdminApiService _api = AdminApiService();

  List<dynamic> _items = [];
  bool _isLoading = true;
  String? _error;
  String _filterPublished = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final bool? isPublished = _filterPublished == 'all' ? null : (_filterPublished == 'published');
      final items = await _api.getArticles(isPublished: isPublished); // Без пагинации
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePublish(int id, bool current) async {
    try {
      await _api.togglePublish(id, !current);
      _loadData();
      _showSnackBar('Статус изменён', Colors.green);
    } catch (e) {
      _showSnackBar('Ошибка: $e', Colors.red);
    }
  }

  Future<void> _deleteArticle(int id, String title) async {
    final confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Удалить статью?'),
        content: Text('"$title" будет удалена безвозвратно.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _api.deleteArticle(id);
        _loadData();
        _showSnackBar('Статья удалена', Colors.green);
      } catch (e) {
        _showSnackBar('Ошибка: $e', Colors.red);
      }
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Статьи (админ)'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              value: _filterPublished,
              decoration: const InputDecoration(labelText: 'Фильтр'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Все статьи')),
                DropdownMenuItem(value: 'published', child: Text('Опубликованные')),
                DropdownMenuItem(value: 'draft', child: Text('Черновики')),
              ],
              onChanged: (v) {
                setState(() => _filterPublished = v!);
                _loadData();
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Ошибка: $_error'))
                    : _items.isEmpty
                        ? const Center(child: Text('Нет статей'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _items.length,
                            itemBuilder: (ctx, i) {
                              final art = _items[i];
                              return Card(
                                child: ListTile(
                                  leading: Icon(
                                    art['is_published'] ? Icons.public : Icons.drafts,
                                    color: art['is_published'] ? Colors.green : Colors.orange,
                                  ),
                                  title: Text(art['title'] ?? 'Без названия'),
                                  subtitle: Text('Автор: ${art['author_detail']?['username'] ?? '?'}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(art['is_published'] ? Icons.visibility_off : Icons.visibility),
                                        onPressed: () => _togglePublish(art['id'], art['is_published']),
                                        tooltip: art['is_published'] ? 'Снять с публикации' : 'Опубликовать',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () async {
                                          await Navigator.push(context, MaterialPageRoute(builder: (_) => ArticleFormScreen(articleId: art['id'])));
                                          _loadData();
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteArticle(art['id'], art['title']),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ArticleFormScreen()));
          _loadData();
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add),
      ),
    );
  }
}