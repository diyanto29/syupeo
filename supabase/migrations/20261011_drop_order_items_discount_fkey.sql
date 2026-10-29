-- =============================================================
-- Migration: Drop foreign key constraint on discount_id for order_items & order_discounts
-- Tanggal: 11 Oktober 2026
-- Alasan: Mencegah error 23503 saat checkout ketika diskon berasal dari Promo (BOGO)
--         atau jika diskon master telah dihapus/diperbarui.
-- =============================================================

ALTER TABLE public.order_items DROP CONSTRAINT IF EXISTS order_items_discount_id_fkey;
ALTER TABLE public.order_discounts DROP CONSTRAINT IF EXISTS order_discounts_discount_id_fkey;
