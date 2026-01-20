-- Force Replica Identity to FULL for critical tables
-- This ensures Realtime sends complete row data for UPDATE/DELETE events
-- Critical for the specific case of "kicking out" members where we need to see the change to NULL.

ALTER TABLE public.profiles REPLICA IDENTITY FULL;
ALTER TABLE public.household_unit REPLICA IDENTITY FULL;
