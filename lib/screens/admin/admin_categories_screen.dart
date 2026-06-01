import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final AdminApiService _api = AdminApiService();
  final TextEditingController _nameController = TextEditingController();

  List<dynamic> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _api.getCategories(); // Без пагинации
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
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) {
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