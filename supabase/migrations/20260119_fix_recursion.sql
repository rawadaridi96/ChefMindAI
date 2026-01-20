-- Fix infinite recursion in profiles policy by using a security definer function
-- The issue was that the policy queried the profiles table, which triggered the policy again endlessly.

-- 1. Create a secure helper function to get the current user's household_id without triggering RLS
-- SECURITY DEFINER means this function runs with the privileges of the creator (postgres/superuser),
-- thus bypassing RLS on the profiles select inside it.
CREATE OR REPLACE FUNCTION get_auth_household_id()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN (SELECT household_id FROM public.profiles WHERE id = auth.uid());
END;
$$;

-- 2. Update the profiles policy to use the helper function
-- We drop the old one first to be safe, though CREATE POLICY usually requires a unique name.
DROP POLICY IF EXISTS "View household members" ON public.profiles;

CREATE POLICY "View household members" ON public.profiles
FOR SELECT
USING (
  -- Current user is the owner
  (auth.uid() = id) OR
  -- OR user is in the same household (fetched securely)
  (
    household_id IS NOT NULL AND
    household_id = get_auth_household_id()
  )
);
