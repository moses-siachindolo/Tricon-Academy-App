-- =============================================================================
-- Tricon Academy — student school / district / grade fields
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Safe to re-run (IF NOT EXISTS).
-- =============================================================================

alter table public.profiles add column if not exists school text;
alter table public.profiles add column if not exists school_district text;
alter table public.profiles add column if not exists grade text;
alter table public.profiles add column if not exists profile_completed boolean not null default false;
