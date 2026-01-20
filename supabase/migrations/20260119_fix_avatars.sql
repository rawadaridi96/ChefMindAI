-- 1. Add avatar_url to Profiles if missing
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- 2. Backfill Avatar URL from Auth Metadata
-- This updates profiles where avatar_url is null/empty but auth.users has metadata
DO $$
BEGIN
    UPDATE public.profiles p
    SET avatar_url = (u.raw_user_meta_data->>'avatar_url')
    FROM auth.users u
    WHERE p.id = u.id 
    AND (p.avatar_url IS NULL OR p.avatar_url = '')
    AND (u.raw_user_meta_data->>'avatar_url') IS NOT NULL;
END $$;

-- 3. Also check for 'picture' key which Google Auth sometimes uses
DO $$
BEGIN
    UPDATE public.profiles p
    SET avatar_url = (u.raw_user_meta_data->>'picture')
    FROM auth.users u
    WHERE p.id = u.id 
    AND (p.avatar_url IS NULL OR p.avatar_url = '')
    AND (u.raw_user_meta_data->>'picture') IS NOT NULL;
END $$;
