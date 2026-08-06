-- =============================================================================
-- Tricon Academy — FULL WIPE: content + all users EXCEPT admins
-- Run in: Supabase Dashboard → SQL Editor → New query → Run
--
-- Project: https://supabase.com/dashboard/project/xkwxgvfagilznywuptgk/sql/new
--
-- KEEPS:
--   • profiles where role = 'admin'
--   • matching auth.users for those admins
--
-- DELETES:
--   • All papers / notes / videos (library_items)
--   • All folders (content_folders)
--   • All library books (library_books)
--   • All student + tutor profiles and auth accounts
--
-- After this: empty Storage bucket "content" (see bottom).
-- =============================================================================

-- 0) See who will be kept (admins) before delete
select id, email, role, full_name
from public.profiles
where role = 'admin'
order by email;

-- 1) Wipe all uploaded content
truncate table public.library_items restart identity cascade;
truncate table public.content_folders restart identity cascade;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'library_books'
  ) then
    execute 'truncate table public.library_books restart identity cascade';
  end if;
end $$;

-- 2) Delete every non-admin auth user.
--    profiles.id → auth.users ON DELETE CASCADE, so student/tutor profiles go too.
delete from auth.users
where id not in (
  select id from public.profiles where role = 'admin'
);

-- 3) Safety: remove any leftover non-admin profile rows (should be none after cascade)
delete from public.profiles
where role is distinct from 'admin';

-- 4) Verify — expect only admin rows, and content counts = 0
select id, email, role, full_name
from public.profiles
order by email;

select
  (select count(*) from public.profiles) as profiles_remaining,
  (select count(*) from public.profiles where role = 'admin') as admins,
  (select count(*) from public.library_items) as library_items,
  (select count(*) from public.content_folders) as content_folders,
  (
    select case
      when exists (
        select 1 from information_schema.tables
        where table_schema = 'public' and table_name = 'library_books'
      )
      then (select count(*) from public.library_books)
      else 0
    end
  ) as library_books;

-- =============================================================================
-- STORAGE FILES (PDFs / videos) — Dashboard
-- =============================================================================
-- 1. Storage → bucket "content"
--    https://supabase.com/dashboard/project/xkwxgvfagilznywuptgk/storage/buckets/content
-- 2. Select all folders/files → Delete
-- =============================================================================
