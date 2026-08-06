-- =============================================================================
-- Tricon Academy — Supabase schema
-- Run this entire file in: Supabase Dashboard → SQL Editor → New query → Run
-- =============================================================================

-- Profiles (one row per auth user)
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  email text not null,
  role text not null check (role in ('student', 'tutor', 'admin')),
  phone text,
  school text,
  school_district text,
  grade text,
  profile_completed boolean not null default false,
  is_blocked boolean not null default false,
  is_removed boolean not null default false,
  highest_education text,
  last_institution text,
  gender text,
  address_location text,
  subject_major text,
  reference_contacts text,
  tutor_approval_status text,
  admin_status_reason text,
  allowed_extra_subjects text,
  pending_subject_request text,
  created_at timestamptz not null default now()
);

-- Safe upgrades for existing projects that already created `profiles`
alter table public.profiles add column if not exists school text;
alter table public.profiles add column if not exists school_district text;
alter table public.profiles add column if not exists grade text;
alter table public.profiles add column if not exists profile_completed boolean not null default false;
alter table public.profiles add column if not exists is_blocked boolean not null default false;
alter table public.profiles add column if not exists is_removed boolean not null default false;
alter table public.profiles add column if not exists highest_education text;
alter table public.profiles add column if not exists last_institution text;
alter table public.profiles add column if not exists gender text;
alter table public.profiles add column if not exists address_location text;
alter table public.profiles add column if not exists subject_major text;
alter table public.profiles add column if not exists reference_contacts text;
alter table public.profiles add column if not exists tutor_approval_status text;
alter table public.profiles add column if not exists admin_status_reason text;
alter table public.profiles add column if not exists allowed_extra_subjects text;
alter table public.profiles add column if not exists pending_subject_request text;

-- Folders under Papers / Notes / Videos for a level + subject
create table if not exists public.content_folders (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  section text not null check (section in ('papers', 'notes', 'videos')),
  level_raw text not null,
  subject_name text not null,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists content_folders_lookup_idx
  on public.content_folders (level_raw, subject_name, section);

-- Uploaded library items (papers, notes, videos)
create table if not exists public.library_items (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('paper', 'note', 'video')),
  title text not null,
  topic text not null default '',
  description text not null default '',
  level_raw text not null,
  subject_name text not null,
  storage_path text,
  original_file_name text not null default '',
  folder_id uuid references public.content_folders (id) on delete set null,
  uploader_id uuid references public.profiles (id) on delete set null,
  uploader_name text not null default 'Staff',
  created_at timestamptz not null default now()
);

create index if not exists library_items_lookup_idx
  on public.library_items (level_raw, subject_name, kind);

-- Auto-create profile when a user signs up (reads name/role from auth metadata)
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
    -- Students must finish school onboarding; tutors finish application form first.
    case when chosen_role = 'student' then false else true end,
    case when chosen_role = 'tutor' then 'none' else null end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Helper: is current user staff?
create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role in ('tutor', 'admin')
  );
$$;

-- RLS
alter table public.profiles enable row level security;
alter table public.content_folders enable row level security;
alter table public.library_items enable row level security;

-- Profiles policies
drop policy if exists "Profiles are readable by authenticated users" on public.profiles;
create policy "Profiles are readable by authenticated users"
  on public.profiles for select
  to authenticated
  using (true);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id);

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

drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

-- Folders: everyone authenticated can read; staff can write
drop policy if exists "Folders readable by authenticated" on public.content_folders;
create policy "Folders readable by authenticated"
  on public.content_folders for select
  to authenticated
  using (true);

drop policy if exists "Staff can insert folders" on public.content_folders;
create policy "Staff can insert folders"
  on public.content_folders for insert
  to authenticated
  with check (public.is_staff());

drop policy if exists "Staff can update folders" on public.content_folders;
create policy "Staff can update folders"
  on public.content_folders for update
  to authenticated
  using (public.is_staff());

drop policy if exists "Staff can delete folders" on public.content_folders;
create policy "Staff can delete folders"
  on public.content_folders for delete
  to authenticated
  using (public.is_staff());

-- Library items
drop policy if exists "Items readable by authenticated" on public.library_items;
create policy "Items readable by authenticated"
  on public.library_items for select
  to authenticated
  using (true);

drop policy if exists "Staff can insert items" on public.library_items;
create policy "Staff can insert items"
  on public.library_items for insert
  to authenticated
  with check (public.is_staff());

drop policy if exists "Staff can update items" on public.library_items;
create policy "Staff can update items"
  on public.library_items for update
  to authenticated
  using (public.is_staff());

drop policy if exists "Staff can delete items" on public.library_items;
create policy "Staff can delete items"
  on public.library_items for delete
  to authenticated
  using (public.is_staff());

-- Storage bucket for PDFs / videos (public read for signed-in clients via public URL)
insert into storage.buckets (id, name, public)
values ('content', 'content', true)
on conflict (id) do update set public = true;

-- Storage policies
drop policy if exists "Authenticated can read content" on storage.objects;
create policy "Authenticated can read content"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'content');

drop policy if exists "Public can read content" on storage.objects;
create policy "Public can read content"
  on storage.objects for select
  to public
  using (bucket_id = 'content');

drop policy if exists "Staff can upload content" on storage.objects;
create policy "Staff can upload content"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'content' and public.is_staff());

drop policy if exists "Staff can update content objects" on storage.objects;
create policy "Staff can update content objects"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'content' and public.is_staff());

drop policy if exists "Staff can delete content objects" on storage.objects;
create policy "Staff can delete content objects"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'content' and public.is_staff());

-- Optional seed: promote a user to admin after they register once
-- update public.profiles set role = 'admin' where email = 'mosesadmin@tricon.com';
-- update public.profiles set role = 'tutor' where email = 'mosestutor@tricon.com';
