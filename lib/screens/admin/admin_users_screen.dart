import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdminApiService _api = AdminApiService();

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
      final result = await _api.getUsersPaginated();
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
    if (_nextUrl == null || _nextUrl!.isEmpty || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await _api.getUsersPaginated(nextUrl: _nextUrl);
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

  Future<void> _toggleRole(dynamic user) async {
    final newStaff = !(user['is_staff'] ?? false);
    try {
      await _api.updateUserRole(user['id'], newStaff);
      if (mounted) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Пользователь ${user['username']} ${newStaff ? 'стал админом' : 'лишён прав админа'}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пользователи'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Ошибка: $_error'))
              : _items.isEmpty
                  ? const Center(child: Text('Нет пользователей'))
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _items.length,
                            itemBuilder: (ctx, i) {
                              final user = _items[i];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: (user['is_staff'] == true) ? Colors.deepPurple : Colors.grey,
                                    child: Text((user['username'] ?? 'U')[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                                  ),
                                  title: Text(user['username'] ?? 'Unknown'),
                                  subtitle: Text(user['email'] ?? 'Нет email'),
                                  trailing: Switch(
                                    value: user['is_staff'] ?? false,
                                    onChanged: (_) => _toggleRole(user),
                                    activeTrackColor: Colors.deepPurple.shade100,
                                    activeThumbColor: Colors.deepPurple,
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
    );
  }
}