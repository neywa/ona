import 'package:flutter/material.dart';

import '../models/article.dart';
import '../repositories/article_repository.dart';
import '../widgets/article_card.dart';
import '../widgets/source_filter_bar.dart';
import 'article_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _pageSize = 30;
  static const double _loadMoreThreshold = 200;

  final ArticleRepository _repository = ArticleRepository();
  final ScrollController _scrollController = ScrollController();

  List<Article> _articles = [];
  List<String> _sources = [];
  String? _selectedSource;
  bool _isLoading = true;
  int _offset = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadSources();
    _loadArticles(reset: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold &&
        !_isLoading &&
        _hasMore) {
      _loadArticles();
    }
  }

  Future<void> _loadSources() async {
    final sources = await _repository.fetchSources();
    if (!mounted) return;
    setState(() {
      _sources = sources;
    });
  }

  Future<void> _loadArticles({bool reset = false}) async {
    if (reset) {
      setState(() {
        _articles = [];
        _offset = 0;
        _hasMore = true;
        _isLoading = true;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    final results = await _repository.fetchArticles(
      limit: _pageSize,
      offset: _offset,
      source: _selectedSource,
    );

    if (!mounted) return;
    setState(() {
      _articles.addAll(results);
      _offset += results.length;
      _hasMore = results.length == _pageSize;
      _isLoading = false;
    });
  }

  void _onSourceSelected(String? source) {
    if (source == _selectedSource) return;
    setState(() {
      _selectedSource = source;
    });
    _loadArticles(reset: true);
  }

  void _onArticleTap(Article article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArticleDetailScreen(article: article),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('OpenShift News'),
            Text(
              '${_articles.length} articles',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          SourceFilterBar(
            sources: _sources,
            selectedSource: _selectedSource,
            onSourceSelected: _onSourceSelected,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadArticles(reset: true),
              child: _buildList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_articles.isEmpty && !_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(child: Text('No articles found')),
        ],
      );
    }

    final showLoader = _isLoading;
    final itemCount = _articles.length + (showLoader ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= _articles.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final article = _articles[index];
        return ArticleCard(
          article: article,
          onTap: () => _onArticleTap(article),
        );
      },
    );
  }
}
