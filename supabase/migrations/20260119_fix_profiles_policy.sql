-- Fix Profiles RLS to allow seeing other household members
-- This is necessary for the Member List to show names instead of "Member X"

-- 1. Drop existing policy if it conflicts (or just add new one if generic select is missing)
-- Assuming we want to ADD to existing permissions.

CREATE POLICY "View household members" ON public.profiles
FOR SELECT
USING (
  -- Allow if users share the same household_id (and it's not null)
  household_id IS NOT NULL AND
  household_id = (
    SELECT household_id FROM public.profiles WHERE id = auth.uid()
  )
);
