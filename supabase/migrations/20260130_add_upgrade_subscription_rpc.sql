-- RPC to allow the app to sync subscription status from RevenueCat to Supabase
-- Example usage: await supabase.rpc('upgrade_user_subscription', { new_tier: 'executive_chef' })

CREATE OR REPLACE FUNCTION public.upgrade_user_subscription(new_tier TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with privileges of the creator (postgres/superuser) to bypass strict RLS if needed, but we check auth.uid()
AS $$
BEGIN
  -- Validate input if necessary, though enum constraint on table usually handles it if using custom type.
  -- Here we trust the app sends valid strings corresponding to the check constraint or type.

  UPDATE public.profiles
  SET 
    subscription_tier = new_tier,
    updated_at = NOW()
  WHERE id = auth.uid(); -- strict security: only update own profile

END;
$$;

-- Grant access to authenticated users
GRANT EXECUTE ON FUNCTION public.upgrade_user_subscription(TEXT) TO authenticated;
