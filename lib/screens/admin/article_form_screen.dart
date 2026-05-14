import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/admin_api_service.dart';
import '../../config.dart';

class ArticleFormScreen extends StatefulWidget {
  final int? articleId;
  const ArticleFormScreen({super.key, this.articleId});

  @override
  State<ArticleFormScreen> createState() => _ArticleFormScreenState();
}

class _ArticleFormScreenState extends State<ArticleFormScreen> {
  final AdminApiService _api = AdminApiService();
  final _formKey = GlobalKey<FormState>();
  
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _contentController = TextEditingController();
  
  int? _selectedCategory;
  List<int> _selectedTags = [];
  bool _isPublished = false;
  List<int> _selectedEditors = [];
  
  List<dynamic> _categories = [];
  List<dynamic> _tags = [];
  List<dynamic> _users = [];
  bool _isLoading = true;
  
  // ДЛЯ КАРТИНКИ
  File? _selectedImage;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String _getFullImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    if (imagePath.startsWith('http')) return imagePath;
    String cleanPath = imagePath;
    if (cleanPath.startsWith('/media/')) {
      cleanPath = cleanPath.substring(6);
    }
    return '${AppConfig.baseUrl}/media/$cleanPath';
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _selectedImage = null;
      _existingImageUrl = null;
    });
  }

  Future<void> _loadData() async {
    try {
      final categories = await _api.getCategories();
      final tags = await _api.getTags();
      final users = await _api.getUsers();
      
      if (mounted) {
        setState(() {
          _categories = categories;
          _tags = tags;
          _users = users;
        });
      }
      
      if (widget.articleId != null) {
        final article = await _api.getArticle(widget.articleId!);
        if (mounted) {
          setState(() {
            _titleController.text = article['title'] ?? '';
            _summaryController.text = article['summary'] ?? '';
            _contentController.text = article['content'] ?? '';
            _selectedCategory = article['category'];
            _selectedTags = List<int>.from(article['tags'] ?? []);
            _isPublished = article['is_published'] ?? false;
            _selectedEditors = List<int>.from(article['editors'] ?? []);
            _existingImageUrl = article['image'];
          });
        }
      }
      
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final data = {
      'title': _titleController.text,
      'summary': _summaryController.text,
      'content': _contentController.text,
      'category': _selectedCategory,
      'tags': _selectedTags,
      'is_published': _isPublished,
      'editors': _selectedEditors,
    };
    
    try {
      if (widget.articleId != null) {
        // Обновление
        await _api.updateArticle(widget.articleId!, data);
        
        // Обновление картинки если выбрана новая
        if (_selectedImage != null) {
          await _api.updateArticleImage(widget.articleId!, _selectedImage!);
        }
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Статья обновлена')));
      } else {
        // Создание
        final created = await _api.createArticle(data);
        
        // Если есть картинка - загружаем
        if (_selectedImage != null && created['id'] != null) {
          await _api.updateArticleImage(created['id'], _selectedImage!);
        }
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Статья создана')));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.articleId != null ? 'Редактировать статью' : 'Создать статью'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ===== БЛОК КАРТИНКИ =====
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'Изображение статьи',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          // Показываем выбранное новое изображение
                          if (_selectedImage != null)
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  child: Image.file(
                                    _selectedImage!,
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                                    onPressed: _removeImage,
                                  ),
                                ),
                              ],
                            )
                          // Показываем существующее изображение (при редактировании)
                          else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  child: Image.network(
                                    _getFullImageUrl(_existingImageUrl),
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      height: 200,
                                      color: Colors.grey.shade200,
                                      child: const Center(child: Icon(Icons.broken_image, size: 50)),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                                    onPressed: _removeImage,
                                  ),
                                ),
                              ],
                            )
                          // Кнопка выбора изображения
                          else
                            InkWell(
                              onTap: _pickImage,
                              child: Container(
                                height: 150,
                                width: double.infinity,
                                color: Colors.grey.shade100,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey.shade600),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Нажмите для выбора изображения',
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Рекомендуемый размер: 1200x600px',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ===== ОСТАЛЬНЫЕ ПОЛЯ =====
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Заголовок'),
                      validator: (v) => v == null || v.isEmpty ? 'Введите заголовок' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _summaryController,
                      decoration: const InputDecoration(labelText: 'Краткое описание'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contentController,
                      decoration: const InputDecoration(labelText: 'Содержание'),
                      maxLines: 10,
                      validator: (v) => v == null || v.isEmpty ? 'Введите содержание' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: 'Категория'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Без категории')),
                        ..._categories.map((c) => DropdownMenuItem(value: c['id'], child: Text(c['name']))),
                      ],
                      onChanged: (v) => setState(() => _selectedCategory = v),
                    ),
                    const SizedBox(height: 16),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'Теги'),
                      child: Wrap(
                        spacing: 8,
                        children: _tags.map((tag) {
                          final isSelected = _selectedTags.contains(tag['id']);
                          return FilterChip(
                            label: Text(tag['name']),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedTags.add(tag['id']);
                                } else {
                                  _selectedTags.remove(tag['id']);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'Редакторы (кто может редактировать)'),
                      child: Wrap(
                        spacing: 8,
                        children: _users.map((user) {
                          final isSelected = _selectedEditors.contains(user['id']);
                          return FilterChip(
                            label: Text(user['username']),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedEditors.add(user['id']);
                                } else {
                                  _selectedEditors.remove(user['id']);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Опубликовано'),
                      value: _isPublished,
                      onChanged: (v) => setState(() => _isPublished = v),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('Сохранить'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}