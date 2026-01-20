-- Secure RPC to join a household
-- This bypasses RLS on household_unit for the check, allowing users to join if they have the ID.

CREATE OR REPLACE FUNCTION public.join_household(target_household_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with privileges of the creator (postgres), bypassing RLS
AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  -- 1. Check if household exists
  SELECT EXISTS (
    SELECT 1 FROM public.household_unit WHERE id = target_household_id
  ) INTO v_exists;

  IF NOT v_exists THEN
    RAISE EXCEPTION 'Household not found';
  END IF;

  -- 2. Update the user's profile
  -- We use auth.uid() to ensure we only update the calling user
  UPDATE public.profiles
  SET 
    household_id = target_household_id,
    household_joined_at = NOW()
  WHERE id = auth.uid();

END;
$$;
