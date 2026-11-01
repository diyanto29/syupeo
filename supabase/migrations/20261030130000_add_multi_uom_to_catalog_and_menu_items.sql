-- ==============================================================================
-- SYUPEO DATABASE MIGRATION SYSTEM
-- Migration: 20261030130000_add_multi_uom_to_catalog_and_menu_items.sql
-- Description: Menambahkan kolom standarisasi multi-satuan (Multi-UOM) dan
--              konversi isi per karton/dus pada master_catalog dan menu_items
-- ==============================================================================

DO $$
BEGIN
  -- 1. Tambah kolom Multi-UOM pada tabel master_catalog
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'master_catalog' AND column_name = 'wholesale_unit') THEN
    ALTER TABLE public.master_catalog ADD COLUMN wholesale_unit VARCHAR(30);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'master_catalog' AND column_name = 'conversion_ratio') THEN
    ALTER TABLE public.master_catalog ADD COLUMN conversion_ratio INTEGER DEFAULT 1;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'master_catalog' AND column_name = 'wholesale_barcode') THEN
    ALTER TABLE public.master_catalog ADD COLUMN wholesale_barcode TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'master_catalog' AND column_name = 'wholesale_base_price') THEN
    ALTER TABLE public.master_catalog ADD COLUMN wholesale_base_price NUMERIC DEFAULT 0;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'master_catalog' AND column_name = 'wholesale_selling_price') THEN
    ALTER TABLE public.master_catalog ADD COLUMN wholesale_selling_price NUMERIC DEFAULT 0;
  END IF;

  -- 2. Tambah kolom Multi-UOM pada tabel menu_items (katalog tiap toko)
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'menu_items' AND column_name = 'wholesale_unit') THEN
    ALTER TABLE public.menu_items ADD COLUMN wholesale_unit VARCHAR(30);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'menu_items' AND column_name = 'conversion_ratio') THEN
    ALTER TABLE public.menu_items ADD COLUMN conversion_ratio INTEGER DEFAULT 1;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'menu_items' AND column_name = 'wholesale_barcode') THEN
    ALTER TABLE public.menu_items ADD COLUMN wholesale_barcode TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'menu_items' AND column_name = 'wholesale_price') THEN
    ALTER TABLE public.menu_items ADD COLUMN wholesale_price INT DEFAULT 0;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'menu_items' AND column_name = 'wholesale_cost_price') THEN
    ALTER TABLE public.menu_items ADD COLUMN wholesale_cost_price INT DEFAULT 0;
  END IF;
END $$;

