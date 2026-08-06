-- =============================================================================
-- Tricon Academy — tutor specialist subject access (extras + requests)
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Safe to re-run.
-- =============================================================================

-- Comma-separated catalogue subjects a tutor may manage beyond subject_major
alter table public.profiles add column if not exists allowed_extra_subjects text;

-- Comma-separated subjects the tutor requested; cleared when super admin grants/denies
alter table public.profiles add column if not exists pending_subject_request text;
