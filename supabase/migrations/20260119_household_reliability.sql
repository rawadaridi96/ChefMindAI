-- 1. Enable RLS on household_unit
ALTER TABLE public.household_unit ENABLE ROW LEVEL SECURITY;

-- 2. Create Policies for household_unit
-- VIEW: Users can view a household if they are the creator OR a member
CREATE POLICY "View household" ON public.household_unit
FOR SELECT
USING (
  auth.uid() = created_by OR 
  id IN (
    SELECT household_id FROM public.profiles WHERE id = auth.uid()
  )
);

-- INSERT: Any authenticated user can create a household
CREATE POLICY "Create household" ON public.household_unit
FOR INSERT
WITH CHECK (
  auth.uid() = created_by
);

-- UPDATE: Only the creator can update the household (e.g. rename)
CREATE POLICY "Update household" ON public.household_unit
FOR UPDATE
USING (
  auth.uid() = created_by
);

-- DELETE: Only the creator can delete the household
CREATE POLICY "Delete household" ON public.household_unit
FOR DELETE
USING (
  auth.uid() = created_by
);

-- 3. Safety: Ensure profiles leave the household if it is deleted
-- Drop the existing constraint (name might vary, so we try standardized names or generic logic)
-- Note: In Supabase/Postgres, we need to know the constraint name. 
-- Since we created it with `REFERENCES` inline, it likely has an auto-generated name.
-- We will try to find and drop it, or just ALTER it if possible. 
-- Standard convention: profiles_household_id_fkey

DO $$
BEGIN
  -- Try to drop the constraint if it exists (to replace it)
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_household_id_fkey') THEN
    ALTER TABLE public.profiles DROP CONSTRAINT profiles_household_id_fkey;
  END IF;
END $$;

-- Re-add the constraint with ON DELETE SET NULL
ALTER TABLE public.profiles
ADD CONSTRAINT profiles_household_id_fkey
FOREIGN KEY (household_id)
REFERENCES public.household_unit(id)
ON DELETE SET NULL;
