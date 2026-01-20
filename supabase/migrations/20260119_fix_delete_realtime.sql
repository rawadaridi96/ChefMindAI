-- Secure RPC to delete a household and ensure Realtime updates for all members
-- Standard CASCADE/SET NULL constraints do not validly trigger Realtime events for related rows.
-- This function explicitly updates profiles first to trigger the event, then deletes the household.

CREATE OR REPLACE FUNCTION public.delete_household(target_household_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_authorized BOOLEAN;
BEGIN
  -- 1. Authorization: Only the creator can delete
  -- We check if the household exists AND was created by the current user
  SELECT EXISTS (
    SELECT 1 FROM public.household_unit 
    WHERE id = target_household_id 
    AND created_by = auth.uid()
  ) INTO v_authorized;

  IF NOT v_authorized THEN
    RAISE EXCEPTION 'Not authorized to delete this household';
  END IF;

  -- 2. Explicitly kick out all members (Updates profiles -> Triggers Realtime for them)
  UPDATE public.profiles
  SET 
    household_id = NULL,
    household_joined_at = NULL
  WHERE household_id = target_household_id;

  -- 3. Delete the household
  DELETE FROM public.household_unit WHERE id = target_household_id;

END;
$$;
