-- 1. Create Recipe Shares Table
CREATE TABLE IF NOT EXISTS public.recipe_shares (
    token UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    original_recipe_id UUID REFERENCES public.saved_recipes(recipe_id) ON DELETE SET NULL, -- Keep share even if original deleted
    snapshot JSONB NOT NULL, -- Stores the recipe data at time of share
    created_by UUID REFERENCES auth.users(id) NOT NULL
);

-- 2. RLS for Creation (Only Executive Chefs can create, but we handle logic in API/App)
-- Ideally, we let authenticated users create if they have the right tier (checked in app).
ALTER TABLE public.recipe_shares ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can create shares" ON public.recipe_shares
FOR INSERT
WITH CHECK (auth.uid() = created_by);

-- 3. RPC to fetch shared recipe by token (Public access via Token)
-- This bypasses RLS because possession of the UUID token IS the permission.
CREATE OR REPLACE FUNCTION get_shared_recipe(token_input UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with privileges of creator (postgres) to bypass RLS on select
AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT snapshot INTO result
    FROM public.recipe_shares
    WHERE token = token_input;
    
    RETURN result;
END;
$$;
