-- 1. Create Household Unit Table
CREATE TABLE IF NOT EXISTS public.household_unit (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    name TEXT NOT NULL,
    created_by UUID REFERENCES auth.users(id) NOT NULL
);

-- 2. Link Profiles to Household
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS household_id UUID REFERENCES public.household_unit(id);

-- 3. Update Shopping Cart for Household Sync
ALTER TABLE public.shopping_cart
ADD COLUMN IF NOT EXISTS household_id UUID REFERENCES public.household_unit(id);

-- 4. Enable Realtime for Shopping Cart (Logic applied via Dashboard usually, but RLS matters)
ALTER PUBLICATION supabase_realtime ADD TABLE shopping_cart;

-- 5. RLS Policies (Example - Adjust as needed)
-- Allow users to see cart items in their household
CREATE POLICY "View household cart items" ON public.shopping_cart
FOR SELECT
USING (
  auth.uid() = user_id OR 
  household_id IN (
    SELECT household_id FROM public.profiles WHERE id = auth.uid()
  )
);

-- Allow users to insert/update items in their household
CREATE POLICY "Manage household cart items" ON public.shopping_cart
FOR ALL
USING (
  auth.uid() = user_id OR 
  household_id IN (
    SELECT household_id FROM public.profiles WHERE id = auth.uid()
  )
);
