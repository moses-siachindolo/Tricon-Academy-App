-- Run after the existing supabase/schema.sql and tutor/student/admin migrations.
-- Transactional, one-time migration. No credentials are stored here.
begin;

create function public.live_active(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
 select exists(select 1 from profiles where id=p_user and not coalesce(is_blocked,false) and not coalesce(is_removed,false));
$$;
create function public.live_admin() returns boolean
language sql stable security definer set search_path = public as $$
 select exists(select 1 from profiles where id=auth.uid() and role='admin' and public.live_active(id));
$$;
create function public.live_subject(p_name text) returns text
language sql immutable set search_path = public as $$
 select case lower(trim(p_name))
 when 'math' then 'mathematics' when 'maths' then 'mathematics'
 when 'chem' then 'chemistry' when 'bio' then 'biology' when 'eng' then 'english'
 when 'civic' then 'civic education' when 'civics' then 'civic education'
 when 'account' then 'accounts' when 'accounting' then 'accounts'
 when 're' then 'religious education' when 'religious' then 'religious education'
 when 'cs' then 'computer science' when 'computers' then 'computer science' when 'ict' then 'computer science'
 else lower(trim(p_name)) end;
$$;
create function public.live_can_teach(p_user uuid, p_subject text) returns boolean
language sql stable security definer set search_path = public as $$
 select exists(select 1 from profiles p where p.id=p_user and public.live_active(p.id) and
 (p.role='admin' or (p.role='tutor' and coalesce(nullif(trim(p.tutor_approval_status),''),'approved')='approved'
 and exists(select 1 from regexp_split_to_table(concat_ws(',',p.subject_major,p.allowed_extra_subjects),'(?i)\s+and\s+|[,;&/]') s
 where public.live_subject(s)=public.live_subject(p_subject)))));
$$;

-- Existing profile policies allow self updates: prevent self-granting admin,
-- tutor approval, or extra subjects, which would bypass live-class permissions.
create function public.live_protect_profile_permissions() returns trigger
language plpgsql security definer set search_path = public as $$
begin
 if auth.role()='service_role' or auth.uid() is null or public.live_admin() then return new; end if;
 if TG_OP='INSERT' then
   if new.role not in ('student','tutor') or coalesce(new.tutor_approval_status,'none') not in ('none','pending')
      or coalesce(new.allowed_extra_subjects,'')<>'' or coalesce(new.is_blocked,false) or coalesce(new.is_removed,false) then
     raise exception 'Profile permissions must be assigned by an administrator';
   end if;
 else
   if new.role is distinct from old.role or new.allowed_extra_subjects is distinct from old.allowed_extra_subjects
      or new.is_blocked is distinct from old.is_blocked or new.is_removed is distinct from old.is_removed
      or (new.tutor_approval_status is distinct from old.tutor_approval_status and
          not (coalesce(old.tutor_approval_status,'none') in ('none','rejected') and new.tutor_approval_status='pending'))
      or (old.role='tutor' and coalesce(nullif(old.tutor_approval_status,''),'approved')='approved' and new.subject_major is distinct from old.subject_major) then
     raise exception 'Teaching permissions must be changed by an administrator';
   end if;
 end if;
 return new;
end $$;
create trigger live_profile_permissions before insert or update on public.profiles for each row execute function public.live_protect_profile_permissions();

create table public.live_lessons (
 id uuid primary key default gen_random_uuid(), tutor_id uuid not null references public.profiles(id),
 subject text not null check(length(trim(subject)) between 1 and 100),
 topic text not null check(length(trim(topic)) between 1 and 200),
 grade text not null check(length(trim(grade)) between 1 and 40),
 scheduled_at timestamptz not null, duration_minutes integer not null check(duration_minutes between 15 and 240),
 status text not null default 'scheduled' check(status in ('scheduled','live','completed','cancelled')),
 recording_enabled boolean not null default false, recording_folder text not null default '',
 recording_active boolean not null default false,
 started_at timestamptz, ended_at timestamptz, created_at timestamptz not null default now(),
 check(not recording_enabled or (length(trim(recording_folder)) between 1 and 300 and recording_folder !~ '(^|/)(\.{1,2})?(/|$)'))
);
create table public.live_lesson_participants (
 id uuid primary key default gen_random_uuid(), lesson_id uuid not null references public.live_lessons(id) on delete cascade,
 user_id uuid not null references public.profiles(id), session_id text not null unique,
 joined_at timestamptz not null default now(), left_at timestamptz, check(left_at is null or left_at>=joined_at)
);
create table public.live_lesson_recordings (
 id uuid primary key default gen_random_uuid(), lesson_id uuid not null references public.live_lessons(id) on delete cascade,
 title text not null, folder text not null, storage_path text not null unique,
 status text not null default 'processing' check(status in ('processing','ready','failed')),
 egress_id text unique, created_at timestamptz not null default now()
);
create table public.live_lesson_reminders (
 lesson_id uuid not null references public.live_lessons(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(), primary key(lesson_id,user_id)
);
create table public.academy_notifications (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
 lesson_id uuid not null references public.live_lessons(id) on delete cascade,
 kind text not null check(kind in ('upcoming','reminder_60','reminder_15','live','recording_ready','cancelled','updated','manual')),
 title text not null, body text not null, event_key text not null,
 created_at timestamptz not null default now(), read_at timestamptz,
 unique(user_id,lesson_id,event_key)
);
create index on public.live_lessons(status,scheduled_at);
create index on public.live_lesson_participants(lesson_id,user_id);
create index on public.academy_notifications(user_id,created_at desc);
create index on public.live_lesson_recordings(lesson_id);

create function public.live_can_view(p_lesson_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
 select public.live_active(auth.uid()) and exists(select 1 from live_lessons l join profiles p on p.id=auth.uid()
 where l.id=p_lesson_id and (p.role='admin' or (p.role='tutor' and l.tutor_id=p.id and public.live_can_teach(p.id,l.subject))
 or (p.role='student' and p.grade=l.grade)));
$$;
create function public.live_can_manage(p_lesson_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
 select public.live_admin() or exists(select 1 from live_lessons where id=p_lesson_id and tutor_id=auth.uid() and public.live_can_teach(auth.uid(),subject));
$$;
alter table public.live_lessons enable row level security;
alter table public.live_lesson_participants enable row level security;
alter table public.live_lesson_recordings enable row level security;
alter table public.live_lesson_reminders enable row level security;
alter table public.academy_notifications enable row level security;
create policy live_read on public.live_lessons for select to authenticated using(public.live_can_view(id));
create policy live_create on public.live_lessons for insert to authenticated with check(
 public.live_can_teach(tutor_id,subject) and (public.live_admin() or tutor_id=auth.uid()) and status='scheduled' and not recording_active and started_at is null and ended_at is null);
create policy live_edit on public.live_lessons for update to authenticated using(public.live_can_manage(id) and status='scheduled')
 with check(public.live_can_teach(tutor_id,subject) and (public.live_admin() or tutor_id=auth.uid()) and status='scheduled' and not recording_active);
create policy attendance_read on public.live_lesson_participants for select to authenticated using(public.live_can_view(lesson_id) and (user_id=auth.uid() or public.live_can_manage(lesson_id)));
create policy recording_read on public.live_lesson_recordings for select to authenticated using(public.live_can_view(lesson_id) and (status='ready' or public.live_can_manage(lesson_id)));
create policy reminder_read on public.live_lesson_reminders for select to authenticated using(user_id=auth.uid() and public.live_can_view(lesson_id));
create policy reminder_create on public.live_lesson_reminders for insert to authenticated with check(user_id=auth.uid() and public.live_can_view(lesson_id) and exists(select 1 from live_lessons where id=lesson_id and status='scheduled'));
create policy reminder_delete on public.live_lesson_reminders for delete to authenticated using(user_id=auth.uid());
create policy notification_read on public.academy_notifications for select to authenticated using(user_id=auth.uid() and public.live_can_view(lesson_id));
create policy notification_read_receipt on public.academy_notifications for update to authenticated using(user_id=auth.uid() and public.live_can_view(lesson_id)) with check(user_id=auth.uid());
revoke all on public.live_lessons, public.live_lesson_participants, public.live_lesson_recordings, public.live_lesson_reminders, public.academy_notifications from anon, authenticated;
grant select,insert on public.live_lessons to authenticated;
grant update(tutor_id,subject,topic,grade,scheduled_at,duration_minutes,recording_enabled,recording_folder) on public.live_lessons to authenticated;
grant select on public.live_lesson_participants,public.live_lesson_recordings to authenticated;
grant select,insert,delete on public.live_lesson_reminders to authenticated;
grant select,update(read_at) on public.academy_notifications to authenticated;
grant all on public.live_lessons,public.live_lesson_participants,public.live_lesson_recordings,public.live_lesson_reminders,public.academy_notifications to service_role;

-- Backend-only fan-out with idempotency keys. Students receive only their grade.
create function public.live_emit(p_lesson_id uuid,p_kind text,p_title text,p_key text) returns void
language sql security definer set search_path = public as $$
 insert into academy_notifications(user_id,lesson_id,kind,title,body,event_key)
 select p.id,l.id,p_kind,p_title,l.subject||': '||l.topic,p_key
 from live_lessons l join profiles p on (p.role='admin' or p.id=l.tutor_id or (p.role='student' and p.grade=l.grade))
 where l.id=p_lesson_id and public.live_active(p.id)
 and (p_kind not in ('reminder_60','reminder_15') or exists(select 1 from live_lesson_reminders r where r.lesson_id=l.id and r.user_id=p.id))
 on conflict(user_id,lesson_id,event_key) do nothing;
$$;
create function public.live_lesson_events() returns trigger
language plpgsql security definer set search_path = public as $$
begin
 if TG_OP='INSERT' then perform public.live_emit(new.id,'upcoming','Upcoming lesson','scheduled');
 elsif new.status is distinct from old.status then
   if new.status='live' then perform public.live_emit(new.id,'live','Class is LIVE','live');
   elsif new.status='cancelled' then perform public.live_emit(new.id,'cancelled','Lesson cancelled','cancelled'); end if;
 elsif row(new.scheduled_at,new.topic,new.grade,new.subject) is distinct from row(old.scheduled_at,old.topic,old.grade,old.subject) then
   perform public.live_emit(new.id,'updated','Lesson updated','updated:'||gen_random_uuid());
 end if;
 return new;
end $$;
create trigger live_lesson_events after insert or update on public.live_lessons for each row execute function public.live_lesson_events();
create function public.live_recording_events() returns trigger
language plpgsql security definer set search_path = public as $$
begin
 if new.status='ready' then
   if TG_OP='INSERT' then perform public.live_emit(new.lesson_id,'recording_ready','Recording ready','recording:'||new.id);
   elsif old.status is distinct from new.status then perform public.live_emit(new.lesson_id,'recording_ready','Recording ready','recording:'||new.id); end if;
 end if;
 return new;
end $$;
create trigger live_recording_events after insert or update on public.live_lesson_recordings for each row execute function public.live_recording_events();
create function public.cancel_live_lesson(p_lesson_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
 if not public.live_can_manage(p_lesson_id) then raise exception 'Not authorized'; end if;
 update live_lessons set status='cancelled' where id=p_lesson_id and status='scheduled';
 if not found then raise exception 'Only scheduled lessons can be cancelled'; end if;
end $$;
create function public.notify_live_lesson(p_lesson_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
 perform 1 from live_lessons where id=p_lesson_id and status in ('scheduled','live') for update;
 if not found or not public.live_can_manage(p_lesson_id) then raise exception 'Not authorized or lesson unavailable'; end if;
 if exists(select 1 from academy_notifications where lesson_id=p_lesson_id and kind='manual' and created_at>now()-interval '5 minutes') then raise exception 'Please wait five minutes before sending another notification'; end if;
 perform public.live_emit(p_lesson_id,'manual','Lesson update','manual:'||gen_random_uuid());
end $$;
create function public.dispatch_live_reminders() returns void
language plpgsql security definer set search_path = public as $$
declare l record; m integer;
begin
 for m in select unnest(array[60,15]) loop
  for l in select * from live_lessons where status='scheduled' and scheduled_at>now() and scheduled_at<=now()+make_interval(mins=>m) loop
   perform public.live_emit(l.id,'reminder_'||m,'Class starts soon', 'reminder:'||m||':'||l.scheduled_at);
  end loop;
 end loop;
end $$;

insert into storage.buckets(id,name,public) values('live-recordings','live-recordings',false)
on conflict(id) do update set public=false;
create policy live_recording_playback on storage.objects for select to authenticated using(
 bucket_id='live-recordings' and exists(select 1 from public.live_lesson_recordings r where r.storage_path=name and r.status='ready' and public.live_can_view(r.lesson_id)));
-- Uploads/deletes are service-role only. Never expose service_role to the app.

-- Trusted webhook events, idempotent even when leave arrives before join.
create function public.live_record_attendance(p_lesson_id uuid,p_user_id uuid,p_session_id text,p_event text,p_at timestamptz) returns void
language plpgsql security definer set search_path = public as $$
begin
 if p_event not in ('participant_joined','participant_left') then raise exception 'Invalid attendance event'; end if;
 insert into live_lesson_participants(lesson_id,user_id,session_id,joined_at,left_at)
 values(p_lesson_id,p_user_id,p_session_id,p_at,case when p_event='participant_left' then p_at else null end)
 on conflict(session_id) do update set
 joined_at=least(live_lesson_participants.joined_at,excluded.joined_at),
 left_at=case when p_event='participant_left' then greatest(live_lesson_participants.left_at,p_at) else live_lesson_participants.left_at end
 where live_lesson_participants.lesson_id=p_lesson_id and live_lesson_participants.user_id=p_user_id;
end $$;
create function public.live_room_finished(p_lesson_id uuid,p_at timestamptz) returns void
language plpgsql security definer set search_path = public as $$
begin
 update live_lessons set status='completed',ended_at=coalesce(ended_at,p_at),recording_active=false where id=p_lesson_id and status in ('live','completed');
 update live_lesson_participants set left_at=greatest(joined_at,p_at) where lesson_id=p_lesson_id and left_at is null;
end $$;

-- PostgreSQL grants EXECUTE to PUBLIC by default; revoke every new function.
do $$ declare f record; begin
 for f in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and (p.proname like 'live\_%' escape '\' or p.proname in ('cancel_live_lesson','notify_live_lesson','dispatch_live_reminders')) loop
 execute format('revoke all on function %s from public, anon, authenticated',f.signature);
 execute format('grant execute on function %s to service_role',f.signature);
 end loop;
end $$;
grant execute on function public.live_active(uuid),public.live_admin(),public.live_subject(text),public.live_can_teach(uuid,text),public.live_can_view(uuid),public.live_can_manage(uuid),public.cancel_live_lesson(uuid),public.notify_live_lesson(uuid) to authenticated;
commit;
-- Enable pg_cron, then schedule (once):
-- select cron.schedule('live-reminders','* * * * *','select public.dispatch_live_reminders()');
