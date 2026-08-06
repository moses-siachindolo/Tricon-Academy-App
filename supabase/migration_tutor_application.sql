-- =============================================================================
-- Tricon Academy — tutor application & approval fields
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
-- Safe to re-run.
-- =============================================================================

alter table public.profiles add column if not exists highest_education text;
alter table public.profiles add column if not exists last_institution text;
alter table public.profiles add column if not exists gender text;
alter table public.profiles add column if not exists address_location text;
alter table public.profiles add column if not exists subject_major text;
alter table public.profiles add column if not exists reference_contacts text;
-- none | pending | approved | rejected
alter table public.profiles add column if not exists tutor_approval_status text;
-- Shown to user when rejected or blocked
alter table public.profiles add column if not exists admin_status_reason text;

-- Existing tutors without a status keep access (app treats null as approved).
-- New tutor registrations set status to 'none' then 'pending' after the form.

-- Keep signup trigger in sync: new tutors start at 'none'; students need school onboarding.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  chosen_role text := coalesce(new.raw_user_meta_data->>'role', 'student');
begin
  insert into public.profiles (
    id, full_name, email, role, phone,
    profile_completed, tutor_approval_status
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    coalesce(new.email, ''),
    chosen_role,
    new.raw_user_meta_data->>'phone',
    case when chosen_role = 'student' then false else true end,
    case when chosen_role = 'tutor' then 'none' else null end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
