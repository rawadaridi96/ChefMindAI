-- Fix for "Database error saving new..." error during signup
-- This ensures the handle_new_user trigger correctly creates profiles with valid subscription_tier

-- 1. Create or replace the handle_new_user function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, subscription_tier, created_at, updated_at)
  VALUES (
    new.id,
    'home_cook',  -- Default tier - must match the constraint
    now(),
    now()
  )
  ON CONFLICT (id) DO NOTHING;  -- Safety: avoid duplicate key errors
  RETURN new;
END;
$$;

-- 2. Ensure the trigger exists on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. Grant necessary permissions
GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
GRANT ALL ON public.profiles TO supabase_auth_admin;
