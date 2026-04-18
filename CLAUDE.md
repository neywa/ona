# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

OpenShift News Aggregator. Two independent subprojects share a single Supabase backend:

- `scraper/` — Python 3.11 ingestion job (RSS → Supabase `articles` table).
- `app/` — Flutter client that reads from the same table.

They do not import from each other; the contract is the Supabase `articles` schema.

## Commands

### Scraper (run from repo root, not from `scraper/`)

```bash
# Install deps (one-time; pyproject.toml is in scraper/ but the package is imported as `scraper.*`)
pip install -e scraper/
# or, matching the GitHub Actions job exactly:
pip install httpx feedparser supabase python-dotenv beautifulsoup4

# Run the full scrape
python -m scraper.main
```

The scraper loads `.env` from the current working directory (root `.env`), which must define `SUPABASE_URL` and `SUPABASE_SECRET_KEY` (service-role key — server-side only, never ship to the Flutter app).

### Flutter app (from `app/`)

```bash
flutter pub get
flutter run                 # picks a connected device/emulator
flutter test                # all tests
flutter test test/foo.dart  # single test file
flutter analyze             # lints (uses analysis_options.yaml → package:flutter_lints)
```

The app reads Supabase credentials from `app/assets/.env` (bundled via `flutter_dotenv`). This file holds the **anon/publishable** key — distinct from the scraper's service-role key.

## Architecture notes

### Scraper data flow

`scraper/main.py` → `sources/rss.py::fetch_all_rss()` → `SupabaseClient.upsert_article()`.

- Feed list is hardcoded in `RSS_SOURCES` in `scraper/sources/rss.py`. Adding a source means appending a `{url, source, tags}` dict — no config file.
- `Article` (`scraper/models.py`) is the single wire format. `to_dict()` defines the row shape upserted into the `articles` table.
- Deduplication is `ON CONFLICT url` — `url` is the stable primary/unique key in Supabase. Rewriting how URLs are extracted will create duplicates.
- All per-entry failures are swallowed and logged; one bad feed entry never kills the run. Don't add `raise`s inside the entry loop without reconsidering this.
- Published dates come from `published_parsed` or `updated_parsed` and are normalized to UTC-aware datetimes. Summaries are HTML-stripped via BeautifulSoup.

### Scheduling

`.github/workflows/scrape.yml` runs `python -m scraper.main` hourly (`0 * * * *`) with `SUPABASE_URL` / `SUPABASE_SECRET_KEY` from repo secrets. The workflow installs deps inline rather than via `pyproject.toml`, so when adding a scraper dependency update **both** `scraper/pyproject.toml` and the workflow's `pip install` line.

### Two env files, two keys

| File | Key type | Consumer |
|---|---|---|
| `/.env` (gitignored) | `SUPABASE_SECRET_KEY` (service role) | scraper, CI |
| `/app/assets/.env` (bundled asset) | `SUPABASE_ANON_KEY` (publishable) | Flutter app |

Never put the service-role key in `app/assets/.env` — that file ships inside the built app.

### Flutter app status

`app/lib/main.dart` is currently the default Flutter counter scaffold. Supabase/auth/feed wiring has not been built yet. `pubspec.yaml` already declares `supabase_flutter`, `cached_network_image`, `timeago`, `url_launcher`, `webview_flutter`, `flutter_dotenv`.
