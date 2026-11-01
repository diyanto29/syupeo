-- ==============================================================================
-- SYUPEO DATABASE MIGRATION SYSTEM
-- Migration: 20261030113000_add_wilayah_fields_to_warehouses_and_orders.sql
-- Description: Menambahkan field Wilayah Indonesia (Provinsi, Kota, Kecamatan, Kelurahan/Desa)
--              dan koordinat GPS presisi (Lat, Long) pada tabel warehouses dan package_fulfillment_orders
-- ==============================================================================

-- 1. Tambah kolom wilayah dan kode pos pada tabel warehouses jika belum ada
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'warehouses' AND column_name = 'district') THEN
    ALTER TABLE public.warehouses ADD COLUMN district VARCHAR(100);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'warehouses' AND column_name = 'village') THEN
    ALTER TABLE public.warehouses ADD COLUMN village VARCHAR(100);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'warehouses' AND column_name = 'postal_code') THEN
    ALTER TABLE public.warehouses ADD COLUMN postal_code VARCHAR(20);
  END IF;
END $$;

-- 2. Tambah kolom wilayah pada tabel package_fulfillment_orders jika belum ada
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'package_fulfillment_orders' AND column_name = 'shipping_province') THEN
    ALTER TABLE public.package_fulfillment_orders ADD COLUMN shipping_province VARCHAR(100);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'package_fulfillment_orders' AND column_name = 'shipping_district') THEN
    ALTER TABLE public.package_fulfillment_orders ADD COLUMN shipping_district VARCHAR(100);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'package_fulfillment_orders' AND column_name = 'shipping_village') THEN
    ALTER TABLE public.package_fulfillment_orders ADD COLUMN shipping_village VARCHAR(100);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'package_fulfillment_orders' AND column_name = 'shipping_postal_code') THEN
    ALTER TABLE public.package_fulfillment_orders ADD COLUMN shipping_postal_code VARCHAR(20);
  END IF;
END $$;

-- 3. Catat ke tabel migration tracker
INSERT INTO public._syupeo_migrations (migration_name, applied_by, notes)
VALUES (
  '20261030113000_add_wilayah_fields_to_warehouses_and_orders.sql',
  'system_admin',
  'Menambahkan standarisasi wilayah.id (Provinsi, Kota, Kecamatan, Desa) dan koordinat Google Maps Places pada warehouses & fulfillment orders'
)
ON CONFLICT (migration_name) DO NOTHING;

