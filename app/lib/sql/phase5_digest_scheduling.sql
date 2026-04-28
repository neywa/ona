-- Phase 5: Personalised digest scheduling
-- Run in Supabase SQL editor before deploying this version.

create table if not exists public.user_digest_prefs (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users(id)
                    on delete cascade unique,
  -- Hour in user's local timezone to deliver the digest (0-23)
  delivery_hour     smallint not null default 7
                    check (delivery_hour between 0 and 23),
  -- IANA timezone string e.g. 'Europe/Prague', 'America/New_York'
  timezone          text not null default 'UTC',
  -- Category filter: [] means all categories (same semantics as alert rules)
  categories        text[] not null default '{}',
  -- Whether scheduling is active; false = on-demand only (default behaviour)
  enabled           boolean not null default false,
  updated_at        timestamptz not null default now()
);

alter table public.user_digest_prefs enable row level security;

create policy "user_digest_prefs: users access own rows"
  on public.user_digest_prefs
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);
