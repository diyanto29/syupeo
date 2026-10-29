-- ====================================================================
-- Migration: Enable Realtime for Orders Table
-- Date: 2026-05-21
-- Broadcasts changes to WebSocket subscribers (Admin Web Live View)
-- ====================================================================

-- 1. Ensure REPLICA IDENTITY is set to FULL (or DEFAULT) so payload contains data
ALTER TABLE public.orders REPLICA IDENTITY FULL;

-- 2. Add orders table to supabase_realtime publication
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
  END IF;
END $$;
