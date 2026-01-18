-- 1. Temporarily Disable RLS
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- 2. Dynamic Policy Wipe: Drop ALL policies on 'profiles' table
-- This handles any custom or hidden policies that might be conflicting.
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT policyname FROM pg_policies WHERE tablename = 'profiles'
    LOOP
        EXECUTE 'DROP POLICY "' || r.policyname || '" ON profiles';
    END LOOP;
END $$;

-- 3. Re-Create Clean Policies

-- Enable read access for users to their own profile
CREATE POLICY "Users can view own profile"
ON profiles FOR SELECT
USING (auth.uid() = id);

-- Enable update access for users to their own profile
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id);

-- Enable insert access for users to their own profile
CREATE POLICY "Users can insert own profile"
ON profiles FOR INSERT
WITH CHECK (auth.uid() = id);

-- 4. Re-Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 5. Grant Permissions (safety check)
GRANT ALL ON profiles TO authenticated;
GRANT ALL ON profiles TO service_role;
