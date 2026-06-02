import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';

class AdminTagsScreen extends StatefulWidget {
  const AdminTagsScreen({super.key});

  @override
  State<AdminTagsScreen> createState() => _AdminTagsScreenState();
}

class _AdminTagsScreenState extends State<AdminTagsScreen> {
  final AdminApiService _api = AdminApiService();
  final TextEditingController _nameController = TextEditingController();

  List<dynamic> _tags = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _nextUrl;
  bool _hasMore = true;
  String? _errorMessage;

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
      _errorMessage = null;
      _tags = [];
      _nextUrl = null;
      _hasMore = true;
    });
    try {
      final result = await _api.getTagsPaginated();
      setState(() {
        _tags = result['items'];
        _nextUrl = result['next'];
        _hasMore = result['next'] != null && result['next'].toString().isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_nextUrl == null || _nextUrl!.isEmpty || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await _api.getTagsPaginated(nextUrl: _nextUrl);
      setState(() {
        _tags.addAll(result['items']);
        _nextUrl = result['next'];
        _hasMore = result['next'] != null && result['next'].toString().isNotEmpty;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _createTag() async {
    _nameController.clear();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать тег'),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Любое название'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Создать')),
        ],
      ),
    );
    if (result == true && _nameController.text.trim().isNotEmpty) {
      try {
        await _api.createTag(_nameController.text.trim());
        _loadData();
        _showSnackBar('Тег создан', Colors.green);
      } catch (e) {
        _showSnackBar('Ошибка: $e', Colors.red);
      }
    }
  }

  Future<void> _editTag(dynamic tag) async {
    _nameController.text = tag['name'];
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать тег'),
        content: TextField(controller: _nameController, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Сохранить')),
        ],
      ),
    );
    if (result == true && _nameController.text.trim().isNotEmpty && _nameController.text.trim() != tag['name']) {
      try {
        await _api.updateTag(tag['id'], _nameController.text.trim());
        _loadData();
        _showSnackBar('Тег обновлён', Colors.green);
      } catch (e) {
        _showSnackBar('Ошибка: $e', Colors.red);
      }
    }
  }

  Future<void> _deleteTag(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить тег?'),
        content: Text('Тег "$name" будет удалён.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _api.deleteTag(id);
        _loadData();
        _showSnackBar('Тег удалён', Colors.green);
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
        title: const Text('Теги'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Ошибка: $_errorMessage'))
              : _tags.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('Нет тегов'),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _createTag,
                            icon: const Icon(Icons.add),
                            label: const Text('Создать тег'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _tags.length,
                            itemBuilder: (context, index) {
                              final tag = _tags[index];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.deepPurple.shade100,
                                    child: const Icon(Icons.local_offer, size: 20, color: Colors.deepPurple),
                                  ),
                                  title: Text(tag['name']),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editTag(tag)),
                                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteTag(tag['id'], tag['name'])),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (_hasMore)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: _isLoadingMore
                                ? const CircularProgressIndicator()
                                : ElevatedButton(
                                    onPressed: _loadMore,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Загрузить ещё'),
                                  ),
                          ),
                      ],
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTag,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add),
      ),
    );
  }
}