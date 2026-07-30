-- ============================================================
-- 003_cron.sql  — pg_cron daily reminder job
-- Prerequisites:
--   1. Enable pg_cron extension: Dashboard → Database → Extensions → pg_cron
--   2. Enable pg_net  extension: Dashboard → Database → Extensions → pg_net
--   3. Deploy the send-reminders Edge Function first
--   4. Replace <YOUR_PROJECT_REF> with your Supabase project reference
--   5. Replace <SUPABASE_SERVICE_ROLE_KEY> with your service role key
-- ============================================================

-- Schedule daily at 08:00 UTC (13:30 IST)
select cron.schedule(
  'daily-payment-reminders',
  '0 8 * * *',
  $$
  select net.http_post(
    url     := 'https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/send-reminders',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer <SUPABASE_SERVICE_ROLE_KEY>'
    ),
    body    := '{}'::jsonb
  );
  $$
);
