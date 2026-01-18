-- Replace 'user@example.com' with the email of the user you want to delete
-- This script deletes the user from the authentication table.
-- If your public tables (profiles, etc.) are set up with "ON DELETE CASCADE", 
-- related data will be automatically removed.

delete from auth.users where email = 'user@example.com';
