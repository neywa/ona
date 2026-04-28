-- Phase 1: Enable RLS on tables that will hold per-user data.
-- Run these in the Supabase SQL editor before deploying Phase 2+.
-- No per-user tables exist yet; this file just enables auth.users access
-- and documents the pattern for Phase 2 onwards.

-- Ensure auth schema is accessible (default in Supabase — confirmed here)
-- All future user tables will follow this pattern:
--
--   alter table public.<table> enable row level security;
--
--   create policy "<table>: users access own rows"
--     on public.<table>
--     for all
--     using (auth.uid() = user_id)
--     with check (auth.uid() = user_id);
--
-- user_id columns must be uuid references auth.users(id) on delete cascade.

-- No schema changes in Phase 1. This file is a placeholder and documentation.
-- Phase 2 (bookmark sync) will add the first real user table.
select 'Phase 1 auth groundwork — no schema changes required' as status;
