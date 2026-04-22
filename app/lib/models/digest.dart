class Digest {
  final String id;
  final DateTime digestDate;
  final String summary;
  final List<Map<String, String>> topArticles;
  final DateTime generatedAt;

  const Digest({
    required this.id,
    required this.digestDate,
    required this.summary,
    required this.topArticles,
    required this.generatedAt,
  });

  factory Digest.fromJson(Map<String, dynamic> json) {
    return Digest(
      id: json['id'] as String,
      digestDate: DateTime.parse(json['digest_date'] as String),
      summary: json['summary'] as String,
      topArticles: List<Map<String, String>>.from(
        (json['top_articles'] as List).map(
          (a) => Map<String, String>.from(
            (a as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
          ),
        ),
      ),
      generatedAt: DateTime.parse(json['generated_at'] as String).toLocal(),
    );
  }
}
