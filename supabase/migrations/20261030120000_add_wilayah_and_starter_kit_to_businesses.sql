-- ==============================================================================
-- SYUPEO DATABASE MIGRATION SYSTEM
-- Migration: 20261030120000_add_wilayah_and_starter_kit_to_businesses.sql
-- Description: Menambahkan koordinat GPS, standardisasi wilayah, dan relasi starter kit pada tabel businesses
-- ==============================================================================

DO $$
BEGIN
  -- 1. Tambah kolom wilayah dan koordinat ke tabel businesses jika belum ada
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'businesses' AND column_name = 'province') THEN
    ALTER TABLE public.businesses ADD COLUMN province VARCHAR(100);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'businesses' AND column_name = 'city') THEN
    ALTER TABLE public.businesses ADD COLUMN city VARCHAR(100);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'businesses' AND column_name = 'district') THEN
    ALTER TABLE public.businesses ADD COLUMN district VARCHAR(100);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'businesses' AND column_name = 'village') THEN
    ALTER TABLE public.businesses ADD COLUMN village VARCHAR(100);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'businesses' AND column_name = 'postal_code') THEN
    ALTER TABLE public.businesses ADD COLUMN postal_code VARCHAR(20);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'businesses' AND column_name = 'latitude') THEN
    ALTER TABLE public.businesses ADD COLUMN latitude DOUBLE PRECISION;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'businesses' AND column_name = 'longitude') THEN
    ALTER TABLE public.businesses ADD COLUMN longitude DOUBLE PRECISION;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'businesses' AND column_name = 'starter_kit_id') THEN
    ALTER TABLE public.businesses ADD COLUMN starter_kit_id UUID REFERENCES public.retail_starter_kits(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'businesses' AND column_name = 'owner_name') THEN
    ALTER TABLE public.businesses ADD COLUMN owner_name VARCHAR(150);
  END IF;

  -- Bolehkan owner_user_id nullable jika toko didaftarkan lewat sales/admin tanpa akun auth terlebih dahulu
  ALTER TABLE public.businesses ALTER COLUMN owner_user_id DROP NOT NULL;
END $$;

-- 2. Stored Procedure untuk Auto-Seed Produk Starter Kit ke Toko Baru
CREATE OR REPLACE FUNCTION public.apply_starter_kit_to_business(
  p_business_id UUID,
  p_starter_kit_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_kit RECORD;
  v_item JSONB;
  v_category_id UUID;
  v_count INT := 0;
BEGIN
  -- 1. Ambil data starter kit
  SELECT * INTO v_kit FROM public.retail_starter_kits WHERE id = p_starter_kit_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Starter kit tidak ditemukan');
  END IF;

  -- 2. Pastikan toko memiliki kategori default 'Produk Starter Kit'
  SELECT id INTO v_category_id FROM public.menu_categories 
  WHERE business_id = p_business_id AND name = 'Paket Usaha' LIMIT 1;
  
  IF v_category_id IS NULL THEN
    INSERT INTO public.menu_categories (business_id, name, is_active)
    VALUES (p_business_id, 'Paket Usaha', true)
    RETURNING id INTO v_category_id;
  END IF;

  -- 3. Loop items_included pada starter kit dan masukkan ke menu_items
  IF v_kit.items_included IS NOT NULL AND jsonb_typeof(v_kit.items_included) = 'array' THEN
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_kit.items_included)
    LOOP
      INSERT INTO public.menu_items (
        business_id,
        category_id,
        name,
        price,
        cost_price,
        stock_quantity,
        unit,
        is_active
      )
      VALUES (
        p_business_id,
        v_category_id,
        COALESCE(v_item->>'name', 'Item Starter Kit'),
        COALESCE((v_item->>'price')::NUMERIC, (v_item->>'retail_price')::NUMERIC, 15000),
        COALESCE((v_item->>'cost_price')::NUMERIC, 12000),
        COALESCE((v_item->>'qty')::INT, (v_item->>'quantity')::INT, 10),
        COALESCE(v_item->>'unit', 'pcs'),
        true
      );
      v_count := v_count + 1;
    END LOOP;
  END IF;

  -- 4. Update starter_kit_id di tabel businesses
  UPDATE public.businesses
  SET starter_kit_id = p_starter_kit_id
  WHERE id = p_business_id;

  RETURN jsonb_build_object('success', true, 'items_added', v_count);
END;
$$;

-- Berikan izin eksekusi ke authenticated dan anon/service role
GRANT EXECUTE ON FUNCTION public.apply_starter_kit_to_business(UUID, UUID) TO authenticated, service_role, anon;

-- 3. Catat ke tabel migration tracker
INSERT INTO public._syupeo_migrations (migration_name, applied_by, notes)
VALUES (
  '20261030120000_add_wilayah_and_starter_kit_to_businesses.sql',
  'system_admin',
  'Menambahkan kolom wilayah (wilayah.id), koordinat GPS, dan relasi starter kit ke tabel businesses serta stored procedure apply_starter_kit_to_business'
)
ON CONFLICT (migration_name) DO NOTHING;
