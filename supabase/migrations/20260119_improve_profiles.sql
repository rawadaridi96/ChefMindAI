-- 1. Add Email and Joined Date to Profiles
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS email TEXT,
ADD COLUMN IF NOT EXISTS household_joined_at TIMESTAMP WITH TIME ZONE;

-- 2. Backfill Email from Auth Schema (Requires permissions, usually works in migration runner)
DO $$
BEGIN
    UPDATE public.profiles p
    SET email = u.email
    FROM auth.users u
    WHERE p.id = u.id AND (p.email IS NULL OR p.email = '');
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Could not backfill emails automatically due to permissions. App will update on next login.';
END $$;

-- 3. Backfill Joined Date (Best guess: use profile created_at for now if they are already in a household)
UPDATE public.profiles
SET household_joined_at = created_at
WHERE household_joined_at IS NULL AND household_id IS NOT NULL;

-- 4. Create a Trigger to keep Email Synced (Optional but good)
-- Note: Requires access to auth.users triggers which is complex. 
-- Instead, we will rely on the App updating 'email' in profiles if it changes, 
-- or a trigger on PUBLIC.PROFILES that strictly validates?
-- For now, simple backfill and column addition is enough. The App logic will handle new joins.
