-- ================================================================
-- Migration: Add Tax Settings to Outlets
-- Description: Adds tax configuration fields to public.outlets table
-- ================================================================

ALTER TABLE public.outlets
  ADD COLUMN IF NOT EXISTS tax_enabled BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS tax_name VARCHAR(50) NOT NULL DEFAULT 'PB1',
  ADD COLUMN IF NOT EXISTS tax_rate NUMERIC(5,2) NOT NULL DEFAULT 10.00,
  ADD COLUMN IF NOT EXISTS is_tax_inclusive BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.outlets.tax_enabled IS 'Menentukan apakah pajak aktif untuk transaksi di outlet ini';
COMMENT ON COLUMN public.outlets.tax_name IS 'Nama pajak yang dicetak pada struk (contoh: PB1, PPN, Pajak Resto)';
COMMENT ON COLUMN public.outlets.tax_rate IS 'Persentase tarif pajak (contoh: 10.00 untuk 10%, 11.00 untuk 11%)';
COMMENT ON COLUMN public.outlets.is_tax_inclusive IS 'True jika harga produk sudah termasuk pajak (inklusif). False jika pajak ditambahkan di atas subtotal (eksklusif)';
