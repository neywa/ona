class Article {
  final String id;
  final String title;
  final String url;
  final String source;
  final List<String> tags;
  final String? summary;
  final DateTime? publishedAt;
  final DateTime createdAt;

  const Article({
    required this.id,
    required this.title,
    required this.url,
    required this.source,
    required this.tags,
    this.summary,
    this.publishedAt,
    required this.createdAt,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      source: json['source'] as String,
      tags: List<String>.from(json['tags'] ?? []),
      summary: json['summary'] as String?,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)?.toLocal()
          : null,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
