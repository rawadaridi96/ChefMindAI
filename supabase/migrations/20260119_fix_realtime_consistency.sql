-- Force Replica Identity to FULL for profiles table
-- This ensures that UPDATE events contain the full old and new row data, 
-- which significantly improves the reliability of Realtime subscriptions.

ALTER TABLE public.profiles REPLICA IDENTITY FULL;

-- Double check Realtime is enabled (Commented out because it throws error if already added)
-- ALTER PUBLICATION supabase_realtime ADD TABLE profiles;
