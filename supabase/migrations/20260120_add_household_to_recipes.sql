-- Add household_id and is_shared columns to saved_recipes
ALTER TABLE saved_recipes
ADD COLUMN IF NOT EXISTS household_id UUID REFERENCES household_unit(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS is_shared BOOLEAN DEFAULT FALSE;

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_saved_recipes_household_id ON saved_recipes(household_id);

-- Enable RLS (should already be enabled, but good practice to ensure)
ALTER TABLE saved_recipes ENABLE ROW LEVEL SECURITY;

-- Policy: Household members can view shared recipes
-- Note: This is in addition to the existing "Users can view their own recipes" (user_id = auth.uid())
CREATE POLICY "Household members can view shared recipes"
ON saved_recipes FOR SELECT
USING (
  household_id IS NOT NULL AND
  household_id IN (
    SELECT household_id FROM profiles WHERE id = auth.uid()
  )
);

-- Policy: Household members can UPDATE shared recipes? 
-- Usually sharing implies read access. If we want them to edit, we need an UPDATE policy too.
-- For now, let's assume they can VIEW.
