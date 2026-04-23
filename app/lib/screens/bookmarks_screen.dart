import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/article.dart';
import '../services/bookmark_service.dart';
import '../theme/app_theme.dart';
import '../widgets/article_card.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<Article> _bookmarks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    setState(() => _isLoading = true);
    final bookmarks = await BookmarkService.instance.getBookmarks();
    if (!mounted) return;
    setState(() {
      _bookmarks = bookmarks;
      _isLoading = false;
    });
  }

  void _openArticle(Article article) {
    launchUrl(
      Uri.parse(article.url),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _showClearConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all bookmarks?'),
        content: const Text('This will remove all saved articles.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kRed),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await BookmarkService.instance.clearAll();
    if (!mounted) return;
    await _loadBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    final secondary = textSecondaryOf(context);
    final muted = textMutedOf(context);

    return Scaffold(
      backgroundColor: bgOf(context),
      appBar: AppBar(
        backgroundColor: bgOf(context),
        title: const Text(
          'SAVED',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        actions: [
          if (_bookmarks.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep_outlined, color: secondary),
              tooltip: 'Clear all',
              onPressed: _showClearConfirmation,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kRed),
        ),
      ),
      body: _buildBody(secondary, muted),
    );
  }

  Widget _buildBody(Color secondary, Color muted) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: kRed),
      );
    }

    if (_bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_outline, size: 64, color: muted),
            const SizedBox(height: 16),
            Text(
              'No saved articles',
              style: TextStyle(
                fontSize: 16,
                color: secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the bookmark icon on any article to save it',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final article = _bookmarks[index];
        return Dismissible(
          key: Key(article.url),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red.withValues(alpha: 0.8),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) async {
            await BookmarkService.instance.removeBookmark(article.url);
            if (!mounted) return;
            setState(() => _bookmarks.removeAt(index));
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ArticleCard(
              article: article,
              onTap: () => _openArticle(article),
            ),
          ),
        );
      },
    );
  }
}
