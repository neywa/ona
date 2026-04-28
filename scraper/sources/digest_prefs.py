"""
Fetches user digest preferences for the current scraper run hour.
Returns only users whose scheduled delivery_hour matches the current
UTC-converted hour, so the hourly scraper run acts as the scheduler.

Uses Python 3.11's stdlib :mod:`zoneinfo` for IANA timezone conversion
rather than adding a third-party ``pytz`` dependency — both expose the
``localize``-equivalent semantics required here.
"""

from dataclasses import dataclass
from datetime import datetime, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from supabase import Client


@dataclass
class UserDigestPref:
    user_id: str
    delivery_hour: int
    timezone: str
    categories: list[str]   # [] = all categories
    fcm_tokens: list[str]   # device tokens for push delivery


def _matches_current_hour(pref_hour: int, tz_name: str, now_utc: datetime) -> bool:
    """
    True if the user's scheduled delivery_hour matches the current
    moment when expressed in their local timezone. Unknown timezone
    strings are skipped (returned as False) rather than crashing the
    whole run — the user can fix the value in the app.
    """
    try:
        local = now_utc.astimezone(ZoneInfo(tz_name))
    except ZoneInfoNotFoundError:
        print(f"[digest_prefs] Unknown IANA timezone: {tz_name!r}")
        return False
    return local.hour == pref_hour


def fetch_due_prefs(supabase: Client) -> list[UserDigestPref]:
    """
    Returns digest prefs for users whose delivery window matches now.

    Algorithm:
    1. Fetch all enabled rows from ``user_digest_prefs``.
    2. For each row, evaluate the user's local hour against now (UTC).
    3. Keep rows where local hour equals ``delivery_hour``.
    4. Join with ``user_device_tokens`` to attach FCM tokens.
    5. Drop users with no registered device tokens.
    """
    prefs_resp = (
        supabase.table("user_digest_prefs")
        .select("user_id, delivery_hour, timezone, categories")
        .eq("enabled", True)
        .execute()
    )
    if not prefs_resp.data:
        return []

    now_utc = datetime.now(timezone.utc)
    due_rows = [
        row
        for row in prefs_resp.data
        if _matches_current_hour(
            int(row["delivery_hour"]),
            row.get("timezone") or "UTC",
            now_utc,
        )
    ]
    if not due_rows:
        return []

    user_ids = list({row["user_id"] for row in due_rows})

    tokens_resp = (
        supabase.table("user_device_tokens")
        .select("user_id, fcm_token")
        .in_("user_id", user_ids)
        .execute()
    )
    token_map: dict[str, list[str]] = {}
    for row in (tokens_resp.data or []):
        token_map.setdefault(row["user_id"], []).append(row["fcm_token"])

    out: list[UserDigestPref] = []
    for row in due_rows:
        tokens = token_map.get(row["user_id"], [])
        if not tokens:
            continue
        out.append(
            UserDigestPref(
                user_id=row["user_id"],
                delivery_hour=int(row["delivery_hour"]),
                timezone=row.get("timezone") or "UTC",
                categories=row.get("categories") or [],
                fcm_tokens=tokens,
            )
        )
    return out
