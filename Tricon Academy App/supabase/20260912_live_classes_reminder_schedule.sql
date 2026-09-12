-- Run AFTER 20260912_live_classes.sql succeeds.
-- First enable Supabase Cron (pg_cron) in the Supabase dashboard.
-- The named job runs the reminder dispatcher every minute.
select cron.schedule(
  'live-reminders',
  '* * * * *',
  'select public.dispatch_live_reminders()'
);
