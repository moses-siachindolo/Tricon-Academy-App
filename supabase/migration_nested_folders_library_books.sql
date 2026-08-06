-- =============================================================================
-- Nested folders + library book review + tutor extra subjects
-- Run in Supabase SQL Editor (safe to re-run).
-- =============================================================================

-- Mini folders inside folders
alter table public.content_folders
  add column if not exists parent_folder_id uuid references public.content_folders (id) on delete cascade;

create index if not exists content_folders_parent_idx
  on public.content_folders (parent_folder_id);

-- Tutor specialist extras
alter table public.profiles add column if not exists allowed_extra_subjects text;
alter table public.profiles add column if not exists pending_subject_request text;

-- Academy library books (tutor/admin uploads, super-admin approval)
create table if not exists public.library_books (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  author text not null,
  summary text not null default '',
  category_raw text not null,
  audience text not null default '',
  pages int not null default 1,
  uploader_id uuid references public.profiles (id) on delete set null,
  uploader_name text not null default 'Staff',
  approval_status text not null default 'pending'
    check (approval_status in ('pending', 'approved', 'rejected')),
  review_reason text,
  storage_path text,
  original_file_name text not null default '',
  created_at timestamptz not null default now()
);

alter table public.library_books enable row level security;

drop policy if exists "Library books readable by authenticated" on public.library_books;
create policy "Library books readable by authenticated"
  on public.library_books for select
  to authenticated
  using (true);

drop policy if exists "Staff can insert library books" on public.library_books;
create policy "Staff can insert library books"
  on public.library_books for insert
  to authenticated
  with check (public.is_staff());

drop policy if exists "Admins can update library books" on public.library_books;
create policy "Admins can update library books"
  on public.library_books for update
  to authenticated
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

drop policy if exists "Admins can delete library books" on public.library_books;
create policy "Admins can delete library books"
  on public.library_books for delete
  to authenticated
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );
