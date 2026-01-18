-- The error "23514" means the value we are trying to save ('chef')
-- violates the existing list of allowed values in the database.

-- 1. Drop the old, restrictive constraint
ALTER TABLE profiles
DROP CONSTRAINT IF EXISTS profiles_subscription_tier_check;

-- 2. CLEANUP: Update any existing rows that don't match our new allowed values.
-- Map old values to new ones if possible, otherwise default to home_cook
UPDATE profiles
SET subscription_tier = 'home_cook'
WHERE subscription_tier NOT IN ('home_cook', 'sous_chef', 'executive_chef');

-- 3. Add a new constraint that matches our App's logic
ALTER TABLE profiles
ADD CONSTRAINT profiles_subscription_tier_check
CHECK (subscription_tier IN ('home_cook', 'sous_chef', 'executive_chef'));
