-- ──────────────────────────────────────────────────────────────────────────────
-- delete_own_account
--
-- Called by the app when the user chooses to delete their account.
-- Deletes the auth.users row (cascades to profiles and all user data via FK).
-- Runs as SECURITY DEFINER so it can touch auth.users, but only allows a user
-- to delete their own account (auth.uid() check).
-- ──────────────────────────────────────────────────────────────────────────────

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Sanity check: only the authenticated user can delete themselves.
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  -- Delete from auth.users — cascades to public.profiles (and anything else
  -- with an ON DELETE CASCADE FK to auth.users).
  delete from auth.users where id = auth.uid();
end;
$$;

-- Only authenticated users can call this function.
revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;
