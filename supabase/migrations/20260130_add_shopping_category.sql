-- Add category column to shopping_items
ALTER TABLE shopping_items ADD COLUMN category text DEFAULT 'Uncategorized';

-- Update existing items to have a default category
UPDATE shopping_items SET category = 'Uncategorized' WHERE category IS NULL;
