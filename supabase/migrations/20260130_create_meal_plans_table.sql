-- Create meal_plans table
CREATE TABLE IF NOT EXISTS public.meal_plans (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date timestamptz NOT NULL,
    meal_type text NOT NULL, -- 'Breakfast', 'Lunch', 'Dinner', 'Snacks'
    recipe_id text,
    recipe_title text,
    custom_description text,
    created_at timestamptz DEFAULT now(),
    PRIMARY KEY (id)
);

-- Enable RLS
ALTER TABLE public.meal_plans ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view their own meal plans"
    ON public.meal_plans FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own meal plans"
    ON public.meal_plans FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own meal plans"
    ON public.meal_plans FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own meal plans"
    ON public.meal_plans FOR DELETE
    USING (auth.uid() = user_id);

-- Realtime
ALTER TABLE public.meal_plans REPLICA IDENTITY FULL;
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR ALL TABLES;
