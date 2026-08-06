-- =============================================================================
-- Tricon Academy — super admin: block / remove accounts
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Safe to re-run.
-- =============================================================================

alter table public.profiles add column if not exists is_blocked boolean not null default false;
alter table public.profiles add column if not exists is_removed boolean not null default false;

-- Super admins can update any profile (block, remove, demote tutors)
drop policy if exists "Admins can update any profile" on public.profiles;
create policy "Admins can update any profile"
  on public.profiles for update
  to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
  );
