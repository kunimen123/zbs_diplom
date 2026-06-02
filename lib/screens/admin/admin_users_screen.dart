import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdminApiService _api = AdminApiService();
  final ScrollController _scrollController = ScrollController();

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
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
        _items = [];
        _nextUrl = null;
        _hasMore = true;
      });
    }
    try {
      final result = await _api.getUsersPaginated();
      if (mounted) {
        setState(() {
          _items = result['items'];
          _nextUrl = result['next'];
          _hasMore = result['next'] != null && result['next'].toString().isNotEmpty;
          _isLoading = false;
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

  Future<void> _loadMore() async {
    if (_nextUrl == null || _nextUrl!.isEmpty || _isLoadingMore) return;
    if (mounted) setState(() => _isLoadingMore = true);
    try {
      final result = await _api.getUsersPaginated(nextUrl: _nextUrl);
      if (mounted) {
        setState(() {
          _items.addAll(result['items']);
          _nextUrl = result['next'];
          _hasMore = result['next'] != null && result['next'].toString().isNotEmpty;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
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
    );
  }
}