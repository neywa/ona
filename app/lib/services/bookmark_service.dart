import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/article.dart';

class BookmarkService {
  static const _key = 'bookmarked_articles';
  static BookmarkService? _instance;
  static BookmarkService get instance => _instance ??= BookmarkService._();
  BookmarkService._();

  SharedPreferences? _prefs;

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<Article>> getBookmarks() async {
    await _init();
    final jsonList = _prefs!.getStringList(_key) ?? [];
    return jsonList
        .map((j) => Article.fromJson(jsonDecode(j) as Map<String, dynamic>))
        .toList();
  }

  Future<bool> isBookmarked(String url) async {
    await _init();
    final jsonList = _prefs!.getStringList(_key) ?? [];
    return jsonList.any((j) {
      final map = jsonDecode(j) as Map<String, dynamic>;
      return map['url'] == url;
    });
  }

  Future<void> addBookmark(Article article) async {
    await _init();
    final jsonList = _prefs!.getStringList(_key) ?? [];
    final exists = jsonList.any((j) {
      final map = jsonDecode(j) as Map<String, dynamic>;
      return map['url'] == article.url;
    });
    if (!exists) {
      jsonList.insert(0, jsonEncode(article.toJson()));
      await _prefs!.setStringList(_key, jsonList);
    }
  }

  Future<void> removeBookmark(String url) async {
    await _init();
    final jsonList = _prefs!.getStringList(_key) ?? [];
    jsonList.removeWhere((j) {
      final map = jsonDecode(j) as Map<String, dynamic>;
      return map['url'] == url;
    });
    await _prefs!.setStringList(_key, jsonList);
  }

  Future<void> toggleBookmark(Article article) async {
    if (await isBookmarked(article.url)) {
      await removeBookmark(article.url);
    } else {
      await addBookmark(article);
    }
  }

  Future<void> clearAll() async {
    await _init();
    await _prefs!.setStringList(_key, []);
  }
}
