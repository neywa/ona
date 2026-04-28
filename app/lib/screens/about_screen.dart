import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/entitlement_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../widgets/auth_sheet.dart';
import '../widgets/paywall_sheet.dart';
import 'submit_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _sources = <_SourceItem>[
    _SourceItem('Red Hat Blog', Icons.rss_feed),
    _SourceItem('Red Hat Developer', Icons.rss_feed),
    _SourceItem('Kubernetes Blog', Icons.rss_feed),
    _SourceItem('CNCF Blog', Icons.rss_feed),
    _SourceItem('Istio Blog', Icons.rss_feed),
    _SourceItem('Hacker News (openshift, kubernetes)', Icons.rss_feed),
    _SourceItem('HackerNoon (kubernetes, devops)', Icons.rss_feed),
    _SourceItem(
      'GitHub Releases — operator-sdk, ROSA, Argo CD, Tekton, Istio, Quay',
      Icons.rocket_launch,
    ),
    _SourceItem(
      'Red Hat Security Data API — OpenShift, Kubernetes, Podman, Quay, Istio, Service Mesh',
      Icons.shield,
    ),
    _SourceItem(
      'OpenShift stable channels (cincinnati-graph-data)',
      Icons.layers,
    ),
  ];

  static const _dataItems = <_DataItem>[
    _DataItem(Icons.schedule, 'Updated every hour automatically'),
    _DataItem(Icons.storage, 'Powered by Supabase'),
    _DataItem(Icons.code, 'Built with Flutter'),
  ];

  static const _links = <_LinkItem>[
    _LinkItem(
      'Privacy Policy',
      'https://neywa.github.io/app-privacy-policies/shiftfeed/',
      Icons.privacy_tip_outlined,
    ),
    _LinkItem('OpenShift Documentation', 'https://docs.openshift.com'),
    _LinkItem('Red Hat Blog', 'https://www.redhat.com/en/blog'),
    _LinkItem('Source Code', 'https://github.com/neywa/ona'),
  ];

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final border = BorderSide(color: theme.dividerColor);
    final cardShape = RoundedRectangleBorder(
      side: border,
      borderRadius: BorderRadius.circular(14),
    );

    Widget sectionTitle(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: onSurface.withValues(alpha: 0.7),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            shape: cardShape,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/icon.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ShiftFeed',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v1.0.0',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'OpenShift Community Intelligence',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: onSurface.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          sectionTitle('Account'),
          Card(
            elevation: 0,
            shape: cardShape,
            clipBehavior: Clip.antiAlias,
            child: const _AccountSection(),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: cardShape,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.add_link_outlined),
              title: const Text('Submit a Link'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubmitScreen()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!kIsWeb) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Row(
                children: [
                  Text(
                    'Notifications',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _ProBadge(),
                ],
              ),
            ),
            Card(
              elevation: 0,
              shape: cardShape,
              clipBehavior: Clip.antiAlias,
              child: const _NotificationsSection(),
            ),
            const SizedBox(height: 16),
          ],
          sectionTitle('Sources'),
          Card(
            elevation: 0,
            shape: cardShape,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final item in _sources)
                  ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.label),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          sectionTitle('Data'),
          Card(
            elevation: 0,
            shape: cardShape,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final item in _dataItems)
                  ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.label),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          sectionTitle('Links'),
          Card(
            elevation: 0,
            shape: cardShape,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final link in _links)
                  ListTile(
                    leading: Icon(link.icon ?? Icons.open_in_browser),
                    title: Text(link.label),
                    onTap: () => _open(link.url),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Made with ♥ by Neywa',
              style: theme.textTheme.bodySmall?.copyWith(
                color: onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SourceItem {
  final String label;
  final IconData icon;
  const _SourceItem(this.label, this.icon);
}

class _DataItem {
  final IconData icon;
  final String label;
  const _DataItem(this.icon, this.label);
}

class _LinkItem {
  final String label;
  final String url;
  final IconData? icon;
  const _LinkItem(this.label, this.url, [this.icon]);
}

class _AccountSection extends StatelessWidget {
  const _AccountSection();

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your Pro features will stop working on this device until you '
          'sign back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await UserService.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: UserService.instance.authStateChanges,
      builder: (context, _) {
        final user = UserService.instance.currentUser;
        final signedIn = user != null;
        if (signedIn) {
          return ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: const Text('Signed in'),
            subtitle: Text(user.email ?? ''),
            trailing: TextButton(
              onPressed: () => _confirmSignOut(context),
              child: const Text('Sign out'),
            ),
          );
        }
        return ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: const Text('No account'),
          subtitle: const Text(
            'Sign in to sync bookmarks and manage your subscription',
          ),
          trailing: TextButton(
            onPressed: () => AuthSheet.show(context),
            child: const Text('Sign in'),
          ),
        );
      },
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEE0000),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _NotificationsSection extends StatefulWidget {
  const _NotificationsSection();

  @override
  State<_NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends State<_NotificationsSection> {
  static const _topics = <_TopicRow>[
    _TopicRow('all', 'Daily AI briefing', Icons.auto_awesome),
    _TopicRow('security', 'CVE alerts', Icons.shield_outlined),
    _TopicRow('releases', 'Release alerts', Icons.rocket_launch_outlined),
  ];

  final Map<String, bool> _enabled = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final t in _topics) {
      _enabled[t.topic] = await NotificationService.getTopicEnabled(t.topic);
    }
    if (!mounted) return;
    setState(() => _loaded = true);
  }

  Future<void> _onToggle(String topic, bool desired) async {
    final isPro = await EntitlementService.instance.isPro();
    if (!mounted) return;
    if (!isPro) {
      // Revert and show paywall — pref is unchanged.
      setState(() => _enabled[topic] = !desired);
      PaywallSheet.show(context, reason: PaywallReason.notifications);
      return;
    }
    setState(() => _enabled[topic] = desired);
    await NotificationService.setTopicEnabled(
      topic,
      enabled: desired,
      isPro: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final t in _topics)
          SwitchListTile(
            secondary: Icon(t.icon),
            title: Text(t.label),
            value: _enabled[t.topic] ?? true,
            onChanged: (v) => _onToggle(t.topic, v),
          ),
      ],
    );
  }
}

class _TopicRow {
  final String topic;
  final String label;
  final IconData icon;
  const _TopicRow(this.topic, this.label, this.icon);
}
