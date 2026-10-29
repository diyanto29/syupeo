-- Migration: Add kitchen_status to orders for Kitchen Display System (KDS)
-- Allows tracking whether an order is pending, cooking, ready to serve, or served.

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS kitchen_status TEXT NOT NULL DEFAULT 'pending';

CREATE INDEX IF NOT EXISTS idx_orders_outlet_kitchen_status 
ON public.orders (outlet_id, kitchen_status);

COMMENT ON COLUMN public.orders.kitchen_status IS 
'Status pemrosesan di dapur: pending (menunggu), cooking (sedang dimasak), ready (siap saji), served (sudah disajikan)';
