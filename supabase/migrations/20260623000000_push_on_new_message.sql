-- ──────────────────────────────────────────────────────────────────────────────
-- Push notification trigger
--
-- Fires the `send-push` Edge Function every time a row is inserted into
-- `direct_messages`, so notifications arrive even when the app is in the
-- background or terminated (the foreground-only Realtime path is no longer
-- the sole delivery mechanism).
--
-- Blocked senders are filtered INSIDE the Edge Function (it checks the
-- `blocked_users` table), so no push is sent for a message from someone the
-- receiver has blocked.
--
-- ⚠️ Prerequisite (run ONCE, see step 2 below): store the project's
-- service-role key in Vault under the name `service_role_key`.
-- ──────────────────────────────────────────────────────────────────────────────

-- 1. pg_net lets Postgres make async outbound HTTP calls (creates the `net` schema).
create extension if not exists pg_net;

-- 2. Store the service-role key in Vault (run this separately, once).
--    Get the key from: Dashboard → Project Settings → API → service_role secret.
--    Uncomment and replace the placeholder, run it, then re-comment it:
--
-- select vault.create_secret(
--   'PASTE_YOUR_SERVICE_ROLE_KEY_HERE',
--   'service_role_key',
--   'Service role key used to call edge functions from DB triggers'
-- );

-- 3. Trigger function: POST the new message row to the send-push function.
create or replace function public.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  service_key text;
begin
  select decrypted_secret into service_key
  from vault.decrypted_secrets
  where name = 'service_role_key'
  limit 1;

  perform net.http_post(
    url := 'https://trzfhrrksvdemowfaodi.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body := jsonb_build_object('record', to_jsonb(new))
  );

  return new;
end;
$$;

-- 4. Bind the function to INSERTs on direct_messages.
drop trigger if exists on_direct_message_insert on public.direct_messages;
create trigger on_direct_message_insert
  after insert on public.direct_messages
  for each row
  execute function public.notify_new_message();
