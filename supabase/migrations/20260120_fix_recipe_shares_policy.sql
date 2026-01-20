-- Create recipe_shares table if it doesn't exist (robustness)
CREATE TABLE IF NOT EXISTS recipe_shares (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token UUID DEFAULT gen_random_uuid(),
    created_by UUID REFERENCES auth.users(id) NOT NULL,
    snapshot JSONB NOT NULL,
    original_recipe_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE recipe_shares ENABLE ROW LEVEL SECURITY;

-- Policy: Allow authenticated users to INSERT their own shares
-- Drop first to avoid conflict if retrying
DROP POLICY IF EXISTS "Users can create shares" ON recipe_shares;

CREATE POLICY "Users can create shares"
ON recipe_shares FOR INSERT
TO authenticated
WITH CHECK (created_by = auth.uid());

-- Policy: Allow users to view their own shares (optional, but good for debugging)
DROP POLICY IF EXISTS "Users can view own shares" ON recipe_shares;

CREATE POLICY "Users can view own shares"
ON recipe_shares FOR SELECT
TO authenticated
USING (created_by = auth.uid());
