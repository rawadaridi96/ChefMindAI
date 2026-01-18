-- The error "23514" means the value we are trying to save ('chef')
-- violates the existing list of allowed values in the database.

-- 1. Drop the old, restrictive constraint
ALTER TABLE profiles
DROP CONSTRAINT IF EXISTS profiles_subscription_tier_check;

-- 2. CLEANUP: Update any existing rows that don't match our new allowed values.
-- This prevents the "violated by some row" error when adding the new constraint.
UPDATE profiles
SET subscription_tier = 'discover'
WHERE subscription_tier NOT IN ('discover', 'chef', 'master_chef')
   OR subscription_tier IS NULL;

-- 3. Add a new constraint that matches our App's logic
ALTER TABLE profiles
ADD CONSTRAINT profiles_subscription_tier_check
CHECK (subscription_tier IN ('discover', 'chef', 'master_chef'));
