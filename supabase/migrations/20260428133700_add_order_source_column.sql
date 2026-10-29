-- =============================================================
-- Tambah kolom order_source pada orders untuk track asal order
-- =============================================================

-- Buat enum type untuk order source
DO $$ BEGIN
  CREATE TYPE public.order_source AS ENUM ('pos', 'qr_self_order', 'waiter', 'online');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS order_source public.order_source NOT NULL DEFAULT 'pos';

COMMENT ON COLUMN public.orders.order_source IS
  'Asal pesanan: pos (kasir), qr_self_order (QR mandiri), waiter (pelayan), online (online order).';
