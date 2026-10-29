-- =============================================================
-- Tambah kolom cashier_name pada orders
-- =============================================================

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS cashier_name text;

COMMENT ON COLUMN public.orders.cashier_name IS
  'Nama kasir yang memproses transaksi.';
