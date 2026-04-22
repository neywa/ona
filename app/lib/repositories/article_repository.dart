import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/article.dart';
import '../models/digest.dart';

class ArticleRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Article>> fetchArticles({
    int limit = 50,
    int offset = 0,
    String? source,
    String? tag,
  }) async {
    try {
      var query = _client.from('articles').select();

      if (source != null) {
        query = query.eq('source', source);
      }
      if (tag != null) {
        query = query.contains('tags', [tag]);
      }

      final response = await query
          .order('published_at', ascending: false, nullsFirst: false)
          .limit(limit)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((row) => Article.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('fetchArticles error: $e');
      return [];
    }
  }

  Future<Digest?> fetchLatestDigest() async {
    try {
      final response = await _client
          .from('digests')
          .select()
          .order('digest_date', ascending: false)
          .limit(1);
      final rows = response as List;
      if (rows.isEmpty) return null;
      return Digest.fromJson(rows.first as Map<String, dynamic>);
    } catch (e) {
      // ignore: avoid_print
      print('fetchLatestDigest error: $e');
      return null;
    }
  }

  Future<List<String>> fetchSources() async {
    try {
      final response = await _client.from('articles').select('source');
      final sources = (response as List)
          .map((row) => (row as Map<String, dynamic>)['source'] as String)
          .toSet()
          .toList()
        ..sort();
      return sources;
    } catch (e) {
      // ignore: avoid_print
      print('fetchSources error: $e');
      return [];
    }
  }
}
