-- =============================================================
-- Keep waiter ownership separate from cashier settlement
-- =============================================================

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS waiter_id UUID REFERENCES auth.users(id);

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS waiter_name text;

COMMENT ON COLUMN public.orders.waiter_id IS
  'User waiter yang membuat / menangani order sebelum dibayar.';

COMMENT ON COLUMN public.orders.waiter_name IS
  'Nama waiter saat order dibuat, disimpan untuk histori.';

UPDATE public.orders
SET
  waiter_id = cashier_id,
  waiter_name = COALESCE(waiter_name, cashier_name)
WHERE order_source = 'waiter'
  AND waiter_id IS NULL
  AND cashier_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS orders_waiter_idx
  ON public.orders (outlet_id, waiter_id, created_at DESC);
