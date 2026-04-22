import base64
import os
import re
import time
from datetime import datetime, timezone

import httpx
import yaml

from scraper.models import Article

# Supabase table setup (run once in the Supabase SQL editor):
#
#   create table if not exists ocp_versions (
#     id uuid primary key default gen_random_uuid(),
#     minor_version text not null unique,
#     latest_stable text not null,
#     updated_at timestamptz default now()
#   );
#
#   alter table ocp_versions enable row level security;
#   create policy "Public read access" on ocp_versions
#     for select using (true);

CINCINNATI_REPO = "openshift/cincinnati-graph-data"
CHANNELS_PATH = "channels"
GITHUB_API = "https://api.github.com"

# Only track versions still receiving updates.
# Versions below this threshold are EOL and ignored.
# Update this when Red Hat EOLs a version.
ACTIVE_MINOR_MINIMUM = 14  # 4.14 is the oldest with active EUS support


def _github_headers() -> dict:
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    token = os.getenv("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def _list_stable_channels() -> list[str]:
    """Return stable-4.*.yaml filenames sorted ascending by minor version."""
    url = f"{GITHUB_API}/repos/{CINCINNATI_REPO}/contents/{CHANNELS_PATH}"
    try:
        response = httpx.get(url, headers=_github_headers(), timeout=10)
        response.raise_for_status()
        files = response.json()
        stable_files = [
            f["name"]
            for f in files
            if re.match(r"^stable-4\.\d+\.yaml$", f["name"])
        ]
        stable_files.sort(
            key=lambda x: int(re.search(r"stable-4\.(\d+)\.yaml", x).group(1))
        )
        return stable_files
    except Exception as e:
        print(f"Failed to list stable channels: {e}")
        return []


def _fetch_channel_versions(filename: str) -> list[str]:
    """Fetch a stable-4.x.yaml file and return its list of version strings."""
    url = (
        f"{GITHUB_API}/repos/{CINCINNATI_REPO}/contents/"
        f"{CHANNELS_PATH}/{filename}"
    )
    try:
        response = httpx.get(url, headers=_github_headers(), timeout=10)
        if response.status_code == 403:
            print("  Rate limited, waiting 10s and retrying...")
            time.sleep(10)
            response = httpx.get(url, headers=_github_headers(), timeout=10)
        response.raise_for_status()
        data = response.json()
        content = base64.b64decode(data["content"]).decode("utf-8")
        parsed = yaml.safe_load(content)
        if isinstance(parsed, list):
            versions = [str(v) for v in parsed if v]
        elif isinstance(parsed, dict):
            versions = [str(v) for v in parsed.get("versions", []) if v]
        else:
            versions = []
        versions = [
            v for v in versions if re.match(r"^4\.\d+\.\d+$", v.strip())
        ]
        return versions
    except Exception as e:
        print(f"Failed to fetch channel {filename}: {e}")
        return []


def _load_known_versions(supabase_client) -> dict[str, str]:
    """Return {minor_version: latest_stable} from the ocp_versions table."""
    try:
        result = (
            supabase_client.client.table("ocp_versions")
            .select("minor_version, latest_stable")
            .execute()
        )
        return {
            row["minor_version"]: row["latest_stable"]
            for row in (result.data or [])
        }
    except Exception as e:
        print(f"Failed to load known versions: {e}")
        return {}


def _save_version(supabase_client, minor: str, latest: str) -> None:
    try:
        supabase_client.client.table("ocp_versions").upsert(
            {
                "minor_version": minor,
                "latest_stable": latest,
                "updated_at": datetime.now(timezone.utc).isoformat(),
            },
            on_conflict="minor_version",
        ).execute()
    except Exception as e:
        print(f"Failed to save version {minor}: {e}")


def fetch_ocp_version_updates(
    supabase_client, seed_only: bool = False
) -> list[Article]:
    """Return Article objects for newly promoted stable OpenShift versions.

    When ``seed_only`` is True, the ocp_versions table is populated with the
    current latest stable per channel but no articles are returned — used on
    first run to avoid flooding the feed with one article per historical
    channel.
    """
    if seed_only:
        print("Seeding ocp_versions table...")
    else:
        print("Fetching OCP stable channel versions...")

    stable_files = _list_stable_channels()
    if not stable_files:
        print("No stable channel files found.")
        return []

    print(
        f"Found {len(stable_files)} stable channels: "
        f"{[f.replace('.yaml', '') for f in stable_files]}"
    )

    known_versions = (
        {} if seed_only else _load_known_versions(supabase_client)
    )
    new_articles: list[Article] = []

    for filename in stable_files:
        match = re.search(r"stable-(4\.\d+)\.yaml", filename)
        if not match:
            continue
        minor = match.group(1)

        minor_int = int(minor.split(".")[1])
        if minor_int < ACTIVE_MINOR_MINIMUM:
            continue

        versions = _fetch_channel_versions(filename)
        time.sleep(0.5)
        if not versions:
            print(f"  {minor}: no versions found")
            continue

        latest = versions[-1].strip()
        known = known_versions.get(minor)

        print(f"  {minor}: latest={latest}, known={known or 'new channel'}")

        if seed_only:
            _save_version(supabase_client, minor, latest)
            continue

        if known is None:
            _save_version(supabase_client, minor, latest)
            article = Article(
                title=(
                    f"OpenShift {minor} stable channel now available — "
                    f"latest: {latest}"
                ),
                url=(
                    f"https://github.com/{CINCINNATI_REPO}/blob/master/"
                    f"{CHANNELS_PATH}/{filename}"
                ),
                source="OCP Versions",
                tags=["release", "openshift", f"ocp-{minor}", "stable-channel"],
                summary=(
                    f"OpenShift {minor} has appeared in the stable channel. "
                    f"The latest stable release is {latest}. "
                    f"This version is now considered production-ready by "
                    f"Red Hat."
                ),
                published_at=datetime.now(timezone.utc),
            )
            new_articles.append(article)
            print(f"  → NEW CHANNEL: {minor} ({latest})")

        elif latest != known:
            _save_version(supabase_client, minor, latest)
            article = Article(
                title=f"OpenShift {latest} is now stable",
                url=(
                    f"https://github.com/{CINCINNATI_REPO}/blob/master/"
                    f"{CHANNELS_PATH}/{filename}"
                ),
                source="OCP Versions",
                tags=[
                    "release",
                    "openshift",
                    f"ocp-{minor}",
                    "stable-channel",
                    "update",
                ],
                summary=(
                    f"OpenShift {minor} stable channel updated from "
                    f"{known} to {latest}. "
                    f"This release has been promoted to the stable channel "
                    f"and is recommended for production clusters."
                ),
                published_at=datetime.now(timezone.utc),
            )
            new_articles.append(article)
            print(f"  → NEW VERSION: {minor}: {known} → {latest}")
        else:
            print("  → no change")

    print(f"OCP version updates: {len(new_articles)} new articles")
    return new_articles
