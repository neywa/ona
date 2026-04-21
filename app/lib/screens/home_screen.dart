import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../models/article.dart';
import '../repositories/article_repository.dart';
import '../theme/app_theme.dart';
import '../utils/favicons.dart';
import '../widgets/article_card.dart';
import 'about_screen.dart';
import 'article_detail_screen.dart';

const double _desktopBreakpoint = 900;

enum ViewMode { grid, list }

const List<String> _popularTags = [
  'Kubernetes',
  'Security',
  'OpenShift',
  'CloudNative',
  'SRE',
  'DevOps',
  'AI',
  'Containers',
];

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
  final TextEditingController _searchController = TextEditingController();

  List<Article> _articles = [];
  List<Article> _filteredArticles = [];
  List<String> _sources = [];
  String? _selectedSource;
  String _searchQuery = '';
  bool _isLoading = true;
  int _offset = 0;
  bool _hasMore = true;
  int _bottomNavIndex = 0;
  ViewMode _viewMode = ViewMode.grid;

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
    _searchController.dispose();
    super.dispose();
  }

  Map<String, int> get _sourceCounts => Map.fromEntries(
    _sources.map(
      (s) => MapEntry(s, _articles.where((a) => a.source == s).length),
    ),
  );

  DateTime? get _lastUpdate {
    if (_articles.isEmpty) return null;
    return _articles.first.publishedAt ?? _articles.first.createdAt;
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
    setState(() => _sources = sources);
  }

  Future<void> _loadArticles({bool reset = false}) async {
    if (reset) {
      setState(() {
        _articles = [];
        _filteredArticles = [];
        _offset = 0;
        _hasMore = true;
        _isLoading = true;
      });
    } else {
      setState(() => _isLoading = true);
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
    _filterArticles();
  }

  List<Article> _applyFilter(List<Article> source) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return List.of(source);
    return source.where((a) {
      final title = a.title.toLowerCase();
      final summary = a.summary?.toLowerCase() ?? '';
      return title.contains(q) || summary.contains(q);
    }).toList();
  }

  void _filterArticles() {
    setState(() => _filteredArticles = _applyFilter(_articles));
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _filterArticles();
  }

  void _onSourceSelected(String? source) {
    if (source == _selectedSource) return;
    setState(() => _selectedSource = source);
    _loadArticles(reset: true);
  }

  void _onArticleTap(Article article, {required bool desktop}) {
    if (kIsWeb || desktop) {
      launchUrl(Uri.parse(article.url), mode: LaunchMode.externalApplication);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArticleDetailScreen(article: article),
        ),
      );
    }
  }

  void _openAbout() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AboutScreen()),
    );
  }

  void _comingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _desktopBreakpoint) {
          return _buildDesktop(context);
        }
        return _buildMobile(context);
      },
    );
  }

  // ================= MOBILE =================

  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.menu, color: kTextSecondary, size: 20),
        title: const Text('OPENSHIFT NEWS'),
        actions: [
          const Icon(Icons.search, color: kTextSecondary, size: 20),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              _viewMode == ViewMode.grid
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
              size: 20,
              color: kTextSecondary,
            ),
            onPressed: () => setState(
              () => _viewMode =
                  _viewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid,
            ),
          ),
          GestureDetector(
            onTap: _openAbout,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: kRed,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 1, color: kRed),
              _buildMobileFilterChips(),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadArticles(reset: true),
        color: kRed,
        backgroundColor: kSurface,
        child: _buildMobileList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: kSurface,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: kRed,
        unselectedItemColor: kTextMuted,
        showUnselectedLabels: true,
        currentIndex: _bottomNavIndex,
        selectedLabelStyle: const TextStyle(fontSize: 10, letterSpacing: 1.0),
        unselectedLabelStyle: const TextStyle(fontSize: 10, letterSpacing: 1.0),
        onTap: (i) {
          if (i == 3) {
            _openAbout();
            return;
          }
          if (i == 0) {
            setState(() => _bottomNavIndex = 0);
            return;
          }
          _comingSoon();
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.rss_feed), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.terminal), label: 'Sources'),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_outline),
            label: 'Saved',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFilterChips() {
    final chips = <Widget>[
      _mobileChip('ALL', _selectedSource == null, () => _onSourceSelected(null)),
      for (final s in _sources)
        _mobileChip(
          s.toUpperCase(),
          _selectedSource == s,
          () => _onSourceSelected(s),
        ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (int i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            chips[i],
          ],
        ],
      ),
    );
  }

  Widget _mobileChip(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: selected ? kRed : kSurface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? Colors.transparent : kBorder,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: selected ? Colors.white : kTextSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    if (_filteredArticles.isEmpty && _searchQuery.isNotEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_off, size: 56, color: kTextMuted),
                const SizedBox(height: 12),
                Text(
                  'No results for "$_searchQuery"',
                  style: const TextStyle(color: kTextSecondary),
                ),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                  child: const Text('Clear search'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_filteredArticles.isEmpty && !_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.rss_feed, size: 56, color: kTextMuted),
                SizedBox(height: 12),
                Text(
                  'No articles yet',
                  style: TextStyle(color: kTextSecondary),
                ),
                SizedBox(height: 4),
                Text(
                  'Pull to refresh',
                  style: TextStyle(color: kTextMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final showLoader = _isLoading;
    final itemCount = _filteredArticles.length + (showLoader ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= _filteredArticles.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: _PollingIndicator(),
          );
        }
        final article = _filteredArticles[index];
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: _viewMode == ViewMode.grid ? 6 : 4,
          ),
          child: ArticleCard(
            article: article,
            onTap: () => _onArticleTap(article, desktop: false),
            compact: _viewMode == ViewMode.list,
          ),
        );
      },
    );
  }

  // ================= DESKTOP =================

  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildLeftSidebar(),
          Expanded(child: _buildDesktopMain()),
          _buildRightSidebar(),
        ],
      ),
    );
  }

  Widget _buildLeftSidebar() {
    final counts = _sourceCounts;
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(right: BorderSide(color: kBorder)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OPENSHIFT NEWS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: kTextPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Precision Intelligence',
                  style: TextStyle(fontSize: 11, color: kTextMuted),
                ),
              ],
            ),
          ),
          const Divider(color: kBorder, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: _navItem(
              icon: Icons.grid_view_rounded,
              label: 'All News',
              selected: _selectedSource == null,
              onTap: () => _onSourceSelected(null),
            ),
          ),
          const Divider(color: kBorder, height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SOURCES',
                style: TextStyle(
                  fontSize: 10,
                  color: kTextMuted,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final s in _sources)
                  _sourceItem(s, counts[s] ?? 0),
              ],
            ),
          ),
          const Divider(color: kBorder, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: kStatusGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _lastUpdate != null
                        ? 'Last update: ${timeago.format(_lastUpdate!)}'
                        : 'Last update: n/a',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: kTextMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? kRed : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: selected ? kRed : kTextSecondary),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? kTextPrimary : kTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceItem(String source, int count) {
    final selected = _selectedSource == source;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onSourceSelected(source),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? kSurface2 : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: selected ? kRed : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: CachedNetworkImage(
                  imageUrl: faviconUrl(source),
                  width: 16,
                  height: 16,
                  placeholder: (_, __) => Container(
                    width: 16,
                    height: 16,
                    color: kBorder,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 16,
                    height: 16,
                    color: kBorder,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  source,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? kTextPrimary : kTextSecondary,
                  ),
                ),
              ),
              Text(
                count.toString().padLeft(2, '0'),
                style: const TextStyle(fontSize: 12, color: kTextMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopMain() {
    return Column(
      children: [
        _buildDesktopTopBar(),
        _buildDesktopFeedHeader(),
        Expanded(child: _buildDesktopGrid()),
      ],
    );
  }

  Widget _buildDesktopTopBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: kSurface,
                border: Border.all(color: kBorder),
                borderRadius: BorderRadius.circular(6),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 13, color: kTextPrimary),
                cursorColor: kRed,
                textAlignVertical: TextAlignVertical.center,
                decoration: const InputDecoration(
                  hintText: 'Search technical intelligence...',
                  hintStyle: TextStyle(color: kTextMuted, fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: kTextMuted, size: 18),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.refresh, color: kTextSecondary),
            tooltip: 'Refresh',
            onPressed: () => _loadArticles(reset: true),
          ),
          const SizedBox(width: 8),
          _ViewToggle(
            viewMode: _viewMode,
            onChanged: (mode) => setState(() => _viewMode = mode),
          ),
          const SizedBox(width: 4),
          const IconButton(
            icon: Icon(Icons.notifications_none, color: kTextSecondary),
            onPressed: null,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.settings, color: kTextSecondary),
            tooltip: 'About',
            onPressed: _openAbout,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFeedHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Engineering Feed',
                  style: TextStyle(
                    color: kTextPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Aggregated insights for SRE and DevOps operations.',
                  style: TextStyle(color: kTextSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          _feedToggleButton('Latest', selected: true, onTap: () {}),
          const SizedBox(width: 8),
          _feedToggleButton('Top', selected: false, onTap: _comingSoon),
        ],
      ),
    );
  }

  Widget _feedToggleButton(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: selected ? kRed : kSurface2,
        foregroundColor: selected ? Colors.white : kTextSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
      child: Text(label.toUpperCase()),
    );
  }

  Widget _buildDesktopGrid() {
    if (_filteredArticles.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 56, color: kTextMuted),
            const SizedBox(height: 12),
            Text(
              'No results for "$_searchQuery"',
              style: const TextStyle(color: kTextSecondary),
            ),
            TextButton(
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
              child: const Text('Clear search'),
            ),
          ],
        ),
      );
    }

    if (_filteredArticles.isEmpty && _isLoading) {
      return const Center(child: _PollingIndicator());
    }

    if (_filteredArticles.isEmpty) {
      return const Center(
        child: Text('No articles yet', style: TextStyle(color: kTextSecondary)),
      );
    }

    final showLoader = _isLoading;
    final itemCount = _filteredArticles.length + (showLoader ? 1 : 0);

    if (_viewMode == ViewMode.grid) {
      return GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 500,
          mainAxisExtent: 220,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= _filteredArticles.length) {
            return const Center(child: _PollingIndicator());
          }
          final article = _filteredArticles[index];
          return ArticleCard(
            article: article,
            onTap: () => _onArticleTap(article, desktop: true),
          );
        },
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= _filteredArticles.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: _PollingIndicator()),
          );
        }
        final article = _filteredArticles[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ArticleCard(
            article: article,
            onTap: () => _onArticleTap(article, desktop: true),
            compact: true,
          ),
        );
      },
    );
  }

  Widget _buildRightSidebar() {
    final counts = _sourceCounts;
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSources = top.take(4).toList();
    final maxCount = topSources.isEmpty
        ? 1
        : topSources.first.value.clamp(1, 1 << 30);

    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(left: BorderSide(color: kBorder)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "TODAY'S TOP SOURCES",
              style: TextStyle(
                fontSize: 10,
                color: kTextMuted,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            for (final entry in topSources) ...[
              _topSourceRow(entry.key, entry.value, maxCount),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            const Divider(color: kBorder),
            const SizedBox(height: 24),
            const Text(
              'POPULAR TAGS',
              style: TextStyle(
                fontSize: 10,
                color: kTextMuted,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _popularTags) _popularTagChip(t),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: kBorder),
            const SizedBox(height: 24),
            _systemStatusCard(),
          ],
        ),
      ),
    );
  }

  Widget _topSourceRow(String source, int count, int maxCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                source,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: kTextPrimary),
              ),
            ),
            Text(
              '$count posts',
              style: const TextStyle(fontSize: 11, color: kTextMuted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final ratio = count / maxCount;
            return Stack(
              children: [
                Container(
                  height: 2,
                  width: constraints.maxWidth,
                  color: kBorder,
                ),
                Container(
                  height: 2,
                  width: constraints.maxWidth * ratio,
                  color: kRed,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _popularTagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kSurface2,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '#$tag',
        style: const TextStyle(
          fontSize: 11,
          color: kTextSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _systemStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface2,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Status',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _StatusDot(),
              SizedBox(width: 8),
              Text(
                'ALL SYSTEMS OPERATIONAL',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  color: kStatusGreen,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Scraper runs every 60 minutes via GitHub Actions',
            style: TextStyle(fontSize: 11, color: kTextMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _PollingIndicator extends StatelessWidget {
  const _PollingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(color: kRed, strokeWidth: 2),
        ),
        SizedBox(height: 12),
        Text(
          'POLLING SOURCES...',
          style: TextStyle(fontSize: 11, color: kTextMuted, letterSpacing: 2),
        ),
        SizedBox(height: 20),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: kStatusGreen,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final ViewMode viewMode;
  final ValueChanged<ViewMode> onChanged;

  const _ViewToggle({required this.viewMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(6),
        color: kSurface,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleBtn(
            icon: Icons.grid_view_rounded,
            selected: viewMode == ViewMode.grid,
            onTap: () => onChanged(ViewMode.grid),
          ),
          Container(width: 1, height: 28, color: kBorder),
          _ToggleBtn(
            icon: Icons.view_list_rounded,
            selected: viewMode == ViewMode.list,
            onTap: () => onChanged(ViewMode.list),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? kRed.withValues(alpha: 0.15) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Center(
            child: Icon(
              icon,
              size: 16,
              color: selected ? kRed : kTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
