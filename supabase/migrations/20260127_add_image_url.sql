-- Add image_url column to shopping_cart table
ALTER TABLE shopping_cart ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Add image_url column to pantry_items table (just in case, though user said it works)
ALTER TABLE pantry_items ADD COLUMN IF NOT EXISTS image_url TEXT;
