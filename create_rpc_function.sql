-- Create a secure function to upgrade a user's subscription
-- This function runs as SECURITY DEFINER, meaning it bypasses the caller's RLS policies
-- IF and ONLY IF the function owner has those privileges (e.g. postgres).

create or replace function upgrade_user_subscription(new_tier text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid;
begin
  -- Get the current authenticated user's ID
  current_user_id := auth.uid();

  -- Safety check: Ensure user is logged in
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Atomic Upsert: Try to insert, if exists, update.
  insert into profiles (id, subscription_tier, updated_at, created_at)
  values (current_user_id, new_tier, now(), now())
  on conflict (id) do update
  set subscription_tier = excluded.subscription_tier,
      updated_at = now();
end;
$$;

-- CRITICAL: Ensure the function is owned by a superuser (postgres)
-- This ensures 'security definer' actually has the power to bypass RLS.
alter function upgrade_user_subscription(text) owner to postgres;

-- Grant execute permission to authenticated users
grant execute on function upgrade_user_subscription(text) to authenticated;
grant execute on function upgrade_user_subscription(text) to service_role;
