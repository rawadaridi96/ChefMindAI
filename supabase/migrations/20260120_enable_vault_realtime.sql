-- Enable Realtime for saved_recipes table
alter publication supabase_realtime add table saved_recipes;

-- Ensure Replica Identity is set to FULL to support deletions with all columns if needed (optional but good for safety)
-- or DEFAULT is usually fine if PK exists.
alter table saved_recipes replica identity full;
