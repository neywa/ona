class CveAlert {
  final String cveId;
  final String title;
  final String articleUrl;
  final DateTime? createdAt;

  const CveAlert({
    required this.cveId,
    required this.title,
    required this.articleUrl,
    this.createdAt,
  });

  factory CveAlert.fromJson(Map<String, dynamic> json) {
    final createdAtStr = json['created_at'] as String?;
    return CveAlert(
      cveId: json['cve_id'] as String,
      title: json['title'] as String,
      articleUrl: json['article_url'] as String,
      createdAt: createdAtStr != null
          ? DateTime.parse(createdAtStr).toLocal()
          : null,
    );
  }
}
