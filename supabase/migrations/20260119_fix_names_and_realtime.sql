-- 1. Backfill Full Name from Auth Metadata
-- This updates profiles where full_name is null/empty but auth.users has metadata
DO $$
BEGIN
    UPDATE public.profiles p
    SET full_name = (u.raw_user_meta_data->>'full_name')
    FROM auth.users u
    WHERE p.id = u.id 
    AND (p.full_name IS NULL OR p.full_name = '')
    AND (u.raw_user_meta_data->>'full_name') IS NOT NULL;
END $$;

-- 2. Enable Realtime for Profiles (Crucial for the "Force Delete" to update UI immediately)
-- We need the client to listen to their own profile changes (specifically household_id column)
ALTER PUBLICATION supabase_realtime ADD TABLE profiles;
