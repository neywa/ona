# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

ShiftFeed — OpenShift / Kubernetes news + intelligence aggregator. Two independent subprojects share a single Supabase backend:

- `scraper/` — Python 3.11 ingestion job (RSS + GitHub Releases + Red Hat CVE API → Supabase). Also generates a daily AI briefing and sends FCM push notifications.
- `app/` — Flutter client (Android, iOS, web, desktop) that reads from the same Supabase tables and subscribes to FCM topics.

They never import from each other. The contract is the Supabase schema (`articles`, `cve_alerts`, `digests`, `ocp_versions`, `submissions` tables) plus FCM topic names.

## Commands

### Scraper (run from repo root, not from `scraper/`)

```bash
# Install deps. The CI workflow installs them inline; pyproject.toml lists the same set.
pip install httpx feedparser supabase python-dotenv beautifulsoup4 google-auth anthropic
# or
pip install -e scraper/

# Run the full scrape (RSS + GitHub releases + Red Hat CVEs → upsert → notify → digest)
python -m scraper.main
```

Loads `.env` from CWD (root `.env`). Required: `SUPABASE_URL`, `SUPABASE_SECRET_KEY`. Optional: `GITHUB_TOKEN` (raises GitHub API rate limit), `ANTHROPIC_API_KEY` (digest generation), `FIREBASE_SERVICE_ACCOUNT_JSON` or `FIREBASE_SERVICE_ACCOUNT_FILE` (FCM push). Without the optional ones the scraper still runs — it just skips that feature with a warning.

### Flutter app (from `app/`)

```bash
flutter pub get
flutter run                        # picks a connected device/emulator
flutter test                       # all tests
flutter test test/widget_test.dart # single test file
flutter analyze                    # lints (uses analysis_options.yaml → flutter_lints)

# Web build (matches deploy_web.yml)
flutter build web --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

The app prefers `--dart-define`d Supabase creds; if those are empty it falls back to `assets/.env` (loaded via `flutter_dotenv`). Web CI uses `--dart-define` and writes an empty `assets/.env` placeholder so the asset bundle doesn't fail.

## Architecture notes

### Scraper data flow

`scraper/main.py` orchestrates four stages:

1. **Fetch + tag** — `sources/rss.py::fetch_all_rss()`, `sources/github_releases.py::fetch_github_releases()`, `sources/security.py::fetch_security_advisories()`. Each result is run through `sources/cve_tagger.py::enrich_with_cve_tags()` which scans title+summary for `CVE-YYYY-N` patterns and adds `cve` / `security` / `CVE-…` tags.
2. **Upsert** — `SupabaseClient.upsert_article()` writes to `articles` (`ON CONFLICT url`). For each `CVE-…` tag found, also upserts a row into `cve_alerts` (`ON CONFLICT cve_id`).
3. **Notify** — `FCMSender` + `NotifiedCache`. `notified_cache.py` uses the `articles.notified` boolean column as the dedupe ledger; only un-notified articles tagged `cve` or `release` produce pushes. A single new alert sends a detailed notification; multiple new alerts collapse into one batch notification (topics: `security`, `releases`).
4. **Digest** — `digest.py::DigestGenerator.generate()` queries today's articles, calls Claude Haiku (`claude-haiku-4-5-20251001`) with a fixed briefing-format prompt, upserts into `digests` (`ON CONFLICT digest_date`), and sends an FCM push to topic `all`. Idempotent per day via `_already_generated_today()`.

### The wire format

`scraper/models.py::Article` is the single dataclass between fetchers and Supabase. `Article.to_dict()` defines the exact row shape — adding a column means updating both this method and the Supabase table. The Flutter side mirrors it in `app/lib/models/article.dart::Article.fromJson` (note `published_at` → `publishedAt`, plus a `created_at` field that the scraper does not set explicitly — Supabase fills it).

### What lives where

- **Supabase reads** from the Flutter client go through [app/lib/repositories/article_repository.dart](app/lib/repositories/article_repository.dart): `articles`, `cve_alerts`, `digests`, `ocp_versions`.
- **Supabase writes** from the Flutter client: only the `submissions` table, via [app/lib/screens/submit_screen.dart](app/lib/screens/submit_screen.dart) using the anon key (unique `url` → `23505` surfaces as "already submitted"). All other writes come from the scraper with the service-role key.
- **On-device only** (not in Supabase): the bookmarks / read-later list, persisted as a JSON string-list in `SharedPreferences` via [app/lib/services/bookmark_service.dart](app/lib/services/bookmark_service.dart). Intentional — keeps RLS simple and avoids a per-user accounts system.

### Deduplication invariants

- `articles.url` is the unique key. Anything that changes how URLs are extracted (canonicalization, query-string trimming) will create duplicates.
- `cve_alerts.cve_id` is the unique key for the CVE table.
- `digests.digest_date` is the unique key for daily digests.
- All per-entry failures inside fetcher loops are swallowed and logged — one bad feed entry never kills the run. Don't add `raise`s inside those loops without reconsidering this.

### Adding a source

- **RSS feed:** append a `{url, source, tags}` dict to `RSS_SOURCES` in `scraper/sources/rss.py`.
- **GitHub repo releases:** append a `{repo, source, tags}` dict to `GITHUB_REPOS` in `scraper/sources/github_releases.py`. Drafts and prereleases are filtered out.
- **Security advisories:** the Red Hat Hydra Security Data API is queried per package keyword in `_PACKAGE_QUERIES` in `scraper/sources/security.py`; relevance is filtered by `_RELEVANT_KEYWORDS` against title + affected_packages.
- **OCP stable-channel versions:** auto-discovered by [scraper/sources/ocp_versions.py](scraper/sources/ocp_versions.py) from the `stable-4.*.yaml` files in `openshift/cincinnati-graph-data`. Upserts into `ocp_versions` (`ON CONFLICT minor_version`) and emits an `Article` for new channels and new stable promotions. There is no per-source config — the fetcher enumerates active minors itself, gated by `ACTIVE_MINOR_MINIMUM` (bump when Red Hat EOLs a minor). First-ever run uses `seed_only=True` so the table is primed without flooding the feed with historical articles. The Flutter side reads the table directly for [app/lib/screens/versions_screen.dart](app/lib/screens/versions_screen.dart) and the desktop sidebar widget.

There is no config file for sources — everything is in code.

### FCM topics

The Flutter client subscribes on launch (Android/iOS only) to:
- `all` — daily digest notifications
- `security` — CVE alerts (single + batch)
- `releases` — release alerts (single + batch)

Notification channel ID is `shiftfeed_alerts` and must match between [scraper/fcm.py](scraper/fcm.py) and [app/lib/services/notification_service.dart](app/lib/services/notification_service.dart). The Firebase project ID is hardcoded in `scraper/fcm.py::FCM_URL`.

### Flutter app shape

[app/lib/main.dart](app/lib/main.dart) initializes Supabase, then conditionally initializes Firebase + `NotificationService` only when `!kIsWeb && (Android || iOS)` — Linux/macOS/Windows/web skip Firebase. `ArticleRepository` ([app/lib/repositories/article_repository.dart](app/lib/repositories/article_repository.dart)) is the only Supabase reader; both `HomeScreen` and `DigestScreen` go through it. `ThemeNotifier` + `provider` drive light/dark switching.

### Two env files, two keys

| File | Key type | Consumer |
|---|---|---|
| `/.env` (gitignored) | `SUPABASE_SECRET_KEY` (service role), `ANTHROPIC_API_KEY`, optional `GITHUB_TOKEN`, optional Firebase SA | scraper, CI |
| `/firebase-service-account.json` (gitignored) | Firebase service account | scraper, local FCM |
| `/app/assets/.env` (bundled asset) | `SUPABASE_ANON_KEY` (publishable) | Flutter app, local builds |
| `--dart-define` (build-time) | `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Flutter web CI |

Never put the service-role key in `app/assets/.env` — that file ships inside the built app.

### Android release signing

[app/android/app/build.gradle.kts](app/android/app/build.gradle.kts) reads `app/android/key.properties` (gitignored) for the release keystore at `keystore/shiftfeed-keystore.jks` (also gitignored — both paths are explicitly excluded in `.gitignore`). If `key.properties` is absent, release builds fall back to the debug signing config — useful locally, never for Play Store uploads.

### CI

- [.github/workflows/scrape.yml](.github/workflows/scrape.yml) runs `python -m scraper.main` hourly (`0 * * * *`) and on `workflow_dispatch`. **Deps are listed inline in the workflow's `pip install` line, not pulled from `pyproject.toml`. Adding a scraper dependency means updating BOTH [scraper/pyproject.toml](scraper/pyproject.toml) AND that pip install line.**
- [.github/workflows/deploy_web.yml](.github/workflows/deploy_web.yml) runs on every push to `main`: `flutter build web` with Supabase creds via `--dart-define`, then `peaceiris/actions-gh-pages` publishes `app/build/web` to the `gh-pages` branch (live at https://neywa.github.io/shiftfeed/, base href `/shiftfeed/`).
