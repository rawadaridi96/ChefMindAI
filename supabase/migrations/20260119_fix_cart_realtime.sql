-- Enable REPLICA IDENTITY FULL for shopping_cart
-- This ensures that DELETE and UPDATE events include the full row data,
-- which is necessary for Realtime filters to correctly match rows based on
-- columns other than the primary key (e.g. household_id).

ALTER TABLE public.shopping_cart REPLICA IDENTITY FULL;
