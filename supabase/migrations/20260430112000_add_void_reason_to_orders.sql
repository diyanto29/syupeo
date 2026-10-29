-- Add void_reason to orders table
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS void_reason TEXT;

COMMENT ON COLUMN public.orders.void_reason IS 'Alasan pembatalan pesanan (void).';
