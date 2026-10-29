-- =============================================================
-- Tambah kolom diskon per item pada order_items
-- =============================================================

ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS discount_id UUID REFERENCES public.discounts(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS discount_name TEXT,
  ADD COLUMN IF NOT EXISTS discount_type public.discount_type,
  ADD COLUMN IF NOT EXISTS discount_percentage NUMERIC(5,2),
  ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(14,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS discount_applied NUMERIC(14,2) NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.order_items.discount_applied IS
  'Jumlah diskon yang di-apply pada item ini (sudah dikalkulasi).';

-- Ubah constraint amount pada order_payments agar >= 0
-- (untuk menangani kasus grand_total = 0 karena full discount)
ALTER TABLE public.order_payments DROP CONSTRAINT IF EXISTS order_payments_amount_positive;
ALTER TABLE public.order_payments ADD CONSTRAINT order_payments_amount_nonnegative CHECK (amount >= 0);
