import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final AdminApiService _api = AdminApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _nameController = TextEditingController();

  List<dynamic> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _nextUrl;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && !_isLoading) {
        _loadMore();
      }
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _items = [];
      _nextUrl = null;
      _hasMore = true;
    });
    try {
      final result = await _api.getCategoriesPaginated();
      setState(() {
        _items = result['items'];
        _nextUrl = result['next'];
        _hasMore = result['next'] != null && result['next'].toString().isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_nextUrl == null || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await _api.getCategoriesPaginated(nextUrl: _nextUrl);
      setState(() {
        _items.addAll(result['items']);
        _nextUrl = result['next'];
        _hasMore = result['next'] != null && result['next'].toString().isNotEmpty;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _create() async {
    _nameController.clear();
    final ok = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Новая категория'),
        content: TextField(controller: _nameController, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Создать')),
        ],
      ),
    );
    if (ok == true && _nameController.text.trim().isNotEmpty) {
      try {
        await _api.createCategory(_nameController.text.trim());
        _loadData();
        _showSnackBar('Категория создана', Colors.green);
      } catch (e) {
        _showSnackBar('Ошибка: $e', Colors.red);
      }
    }
  }

  Future<void> _edit(dynamic item) async {
    _nameController.text = item['name'];
    final ok = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Редактировать'),
        content: TextField(controller: _nameController, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Сохранить')),
        ],
      ),
    );
    if (ok == true && _nameController.text.trim().isNotEmpty && _nameController.text.trim() != item['name']) {
      try {
        await _api.updateCategory(item['id'], _nameController.text.trim());
        _loadData();
        _showSnackBar('Категория обновлена', Colors.green);
      } catch (e) {
        _showSnackBar('Ошибка: $e', Colors.red);
      }
    }
  }

  Future<void> _delete(int id, String name) async {
    final confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Удалить?'),
        content: Text('Категория "$name" будет удалена.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Нет')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Да', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _api.deleteCategory(id);
        _loadData();
        _showSnackBar('Категория удалена', Colors.green);
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
        title: const Text('Категории'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Ошибка: $_error'))
              : _items.isEmpty
                  ? const Center(child: Text('Нет категорий'))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length + (_hasMore ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == _items.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        }
                        final item = _items[i];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.category, color: Colors.deepPurple),
                            title: Text(item['name']),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _edit(item)),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(item['id'], item['name'])),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add),
      ),
    );
  }
}