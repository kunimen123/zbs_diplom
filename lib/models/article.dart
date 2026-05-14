class Article {
  final int id;
  final String title;
  final String slug;
  final String summary;
  final String content;
  final int? categoryId;
  final String? categoryName;
  final List<int> tagIds;
  final List<String> tagNames;
  final int? authorId;
  final String? authorUsername;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? image;
  final int favoritesCount;
  final bool isFavorited;
  final List<int> editorIds;
  final List<int> favoritedByIds;

  Article({
    required this.id,
    required this.title,
    required this.slug,
    required this.summary,
    required this.content,
    this.categoryId,
    this.categoryName,
    required this.tagIds,
    required this.tagNames,
    this.authorId,
    this.authorUsername,
    required this.isPublished,
    required this.createdAt,
    this.updatedAt,
    this.image,
    required this.favoritesCount,
    required this.isFavorited,
    required this.editorIds,
    required this.favoritedByIds,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'],
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      summary: json['summary'] ?? '',
      content: json['content'] ?? '',
      categoryId: json['category'],
      categoryName: json['category_detail']?['name'],
      tagIds: List<int>.from(json['tags'] ?? []),
      tagNames: (json['tags_detail'] as List<dynamic>?)
              ?.map((t) => t['name'] as String)
              .toList() ??
          [],
      authorId: json['author'],
      authorUsername: json['author_detail']?['username'],
      isPublished: json['is_published'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      image: json['image'],
      favoritesCount: json['favorites_count'] ?? 0,
      isFavorited: json['is_favorited'] ?? false,
      editorIds: List<int>.from(json['editors'] ?? []),
      favoritedByIds: List<int>.from(json['favorited_by'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'slug': slug,
      'summary': summary,
      'content': content,
      'category': categoryId,
      'tags': tagIds,
      'is_published': isPublished,
      'editors': editorIds,
    };
  }
}