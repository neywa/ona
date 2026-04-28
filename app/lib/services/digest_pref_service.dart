/// Manages the user's digest scheduling preferences stored in
/// `user_digest_prefs`. Controls delivery time, timezone, and category
/// filter for the personalised AI briefing the scraper sends each user
/// at their chosen hour.
///
/// All methods are no-ops when not signed in — callers should gate UI
/// access on [UserService.isSignedIn] / Pro before showing the
/// scheduling sheet.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_service.dart';

const String _kTable = 'user_digest_prefs';

/// One row of the `user_digest_prefs` table — the user's complete
/// scheduling preferences for the personalised digest.
class DigestPrefs {
  /// Server-assigned id, null before the row is first persisted.
  final String? id;

  /// Hour-of-day, 0–23, expressed in the user's local [timezone].
  final int deliveryHour;

  /// IANA timezone name, e.g. `Europe/Prague`.
  final String timezone;

  /// Categories the digest should cover (empty list ⇒ all categories).
  final List<String> categories;

  /// Whether the schedule is active. False ⇒ on-demand digest only.
  final bool enabled;

  const DigestPrefs({
    this.id,
    this.deliveryHour = 7,
    this.timezone = 'UTC',
    this.categories = const [],
    this.enabled = false,
  });

  factory DigestPrefs.fromJson(Map<String, dynamic> json) {
    return DigestPrefs(
      id: json['id'] as String?,
      deliveryHour: (json['delivery_hour'] as num?)?.toInt() ?? 7,
      timezone: (json['timezone'] as String?) ?? 'UTC',
      categories: List<String>.from(json['categories'] ?? const []),
      enabled: json['enabled'] as bool? ?? false,
    );
  }

  /// Serialises for an upsert. `user_id` is added by the service;
  /// `id` and `updated_at` are managed by the database.
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'delivery_hour': deliveryHour,
        'timezone': timezone,
        'categories': categories,
        'enabled': enabled,
      };

  DigestPrefs copyWith({
    String? id,
    int? deliveryHour,
    String? timezone,
    List<String>? categories,
    bool? enabled,
  }) {
    return DigestPrefs(
      id: id ?? this.id,
      deliveryHour: deliveryHour ?? this.deliveryHour,
      timezone: timezone ?? this.timezone,
      categories: categories ?? this.categories,
      enabled: enabled ?? this.enabled,
    );
  }
}

class DigestPrefService {
  DigestPrefService._();
  static final DigestPrefService _instance = DigestPrefService._();
  static DigestPrefService get instance => _instance;

  SupabaseClient get _client => Supabase.instance.client;

  /// Returns the row for the signed-in user, or [DigestPrefs] defaults
  /// if no row exists yet (first-time user).
  Future<DigestPrefs> getPrefs() async {
    final uid = UserService.instance.currentUser?.id;
    if (uid == null) return const DigestPrefs();
    try {
      final row = await _client
          .from(_kTable)
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) return const DigestPrefs();
      return DigestPrefs.fromJson(row);
    } catch (e) {
      debugPrint('DigestPrefService.getPrefs failed: $e');
      rethrow;
    }
  }

  /// Upserts the user's prefs. Uses `user_id` as the conflict target.
  Future<void> savePrefs(DigestPrefs prefs) async {
    final uid = UserService.instance.currentUser?.id;
    if (uid == null) return;
    try {
      final payload = {
        ...prefs.toJson(),
        'user_id': uid,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }..remove('id');
      await _client.from(_kTable).upsert(payload, onConflict: 'user_id');
    } catch (e) {
      debugPrint('DigestPrefService.savePrefs failed: $e');
      rethrow;
    }
  }

  /// Best-effort IANA timezone for the current device.
  ///
  /// Async because [FlutterTimezone.getLocalTimezone] crosses a platform
  /// channel. Falls back to `'UTC'` on any failure (typically web /
  /// desktop where the plugin has no implementation) so the caller can
  /// just `await` and pre-fill a TextField.
  static Future<String> deviceTimezone() async {
    try {
      final tz = await FlutterTimezone.getLocalTimezone();
      if (tz.isEmpty) return 'UTC';
      return tz;
    } catch (e) {
      debugPrint('deviceTimezone fallback to UTC: $e');
      return 'UTC';
    }
  }
}
