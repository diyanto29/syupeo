-- ==============================================================================
-- SYUPEO DATABASE MIGRATION SYSTEM
-- Migration: 20261031174500_confirm_package_delivery_and_policies.sql
-- Description:
-- 1. Pastikan tabel order_discounts dan menu_package_items beserta FK ada di public schema
-- 2. Sinkronisasi kolom outlets & RLS aman
-- 3. Pastikan visual_index di menu_categories tidak pernah NULL (mencegah error type Null is not subtype of int)
-- 4. Tabel retail_starter_kit_items dengan kolom category per produk
-- 5. Stored Procedure 100% DINAMIS apply_starter_kit_to_business yang otomatis membuat & memetakan kategori produk
-- 6. Backfill otomatis: Update semua produk toko yang sudah ada agar terhubung ke kategori aslinya
-- 7. Reload schema PostgREST Supabase
-- ==============================================================================

-- 1. TABEL order_discounts & FOREIGN KEY KE orders
CREATE TABLE IF NOT EXISTS public.order_discounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL,
  discount_id UUID REFERENCES public.discounts(id) ON DELETE SET NULL,
  name TEXT NOT NULL DEFAULT 'Diskon',
  type TEXT NOT NULL DEFAULT 'percentage',
  percentage_value NUMERIC(5,2),
  amount_value NUMERIC(14,2),
  max_discount_amount NUMERIC(14,2),
  applied_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT order_discounts_name_not_blank CHECK (btrim(name) <> '')
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'order_discounts_order_id_fkey'
  ) THEN
    ALTER TABLE public.order_discounts
    ADD CONSTRAINT order_discounts_order_id_fkey
    FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS order_discounts_order_idx ON public.order_discounts (order_id);
ALTER TABLE public.order_discounts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "order_discounts_select" ON public.order_discounts;
CREATE POLICY "order_discounts_select" ON public.order_discounts FOR SELECT USING (true);
DROP POLICY IF EXISTS "order_discounts_manage" ON public.order_discounts;
CREATE POLICY "order_discounts_manage" ON public.order_discounts FOR ALL USING (true);

-- 2. TABEL menu_package_items & FOREIGN KEY KE menu_items
CREATE TABLE IF NOT EXISTS public.menu_package_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_menu_item_id UUID NOT NULL,
  component_menu_item_id UUID NOT NULL,
  quantity INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'menu_package_items_package_menu_item_id_fkey'
  ) THEN
    ALTER TABLE public.menu_package_items
    ADD CONSTRAINT menu_package_items_package_menu_item_id_fkey
    FOREIGN KEY (package_menu_item_id) REFERENCES public.menu_items(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'menu_package_items_component_menu_item_id_fkey'
  ) THEN
    ALTER TABLE public.menu_package_items
    ADD CONSTRAINT menu_package_items_component_menu_item_id_fkey
    FOREIGN KEY (component_menu_item_id) REFERENCES public.menu_items(id) ON DELETE CASCADE;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_menu_package_items_package_id ON public.menu_package_items(package_menu_item_id);
CREATE INDEX IF NOT EXISTS idx_menu_package_items_component_id ON public.menu_package_items(component_menu_item_id);
ALTER TABLE public.menu_package_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "menu_package_items_select_all" ON public.menu_package_items;
CREATE POLICY "menu_package_items_select_all" ON public.menu_package_items FOR SELECT USING (true);
DROP POLICY IF EXISTS "menu_package_items_manage_all" ON public.menu_package_items;
CREATE POLICY "menu_package_items_manage_all" ON public.menu_package_items FOR ALL USING (true);

-- 3. SINKRONISASI KOLOM OUTLETS & MENU_ITEMS & MENU_CATEGORIES
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS timezone TEXT NOT NULL DEFAULT 'Asia/Jakarta';
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS geofence_radius INT DEFAULT 5000;
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS is_geofence_active BOOLEAN DEFAULT true;
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS tax_enabled BOOLEAN DEFAULT false;
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS tax_name TEXT DEFAULT 'PB1';
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS tax_rate NUMERIC(5,2) DEFAULT 10.0;
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS is_tax_inclusive BOOLEAN DEFAULT false;

-- Pastikan visual_index di menu_categories ada dan TIDAK PERNAH NULL
ALTER TABLE public.menu_categories ADD COLUMN IF NOT EXISTS visual_index INT DEFAULT 0;
ALTER TABLE public.menu_categories ADD COLUMN IF NOT EXISTS is_visible_in_all_outlets BOOLEAN DEFAULT true;
ALTER TABLE public.menu_categories ADD COLUMN IF NOT EXISTS visible_outlet_ids UUID[] DEFAULT '{}'::uuid[];
UPDATE public.menu_categories SET visual_index = 0 WHERE visual_index IS NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'menu_items' AND column_name = 'category'
  ) THEN
    ALTER TABLE public.menu_items ALTER COLUMN category DROP NOT NULL;
  END IF;
END $$;

ALTER TABLE public.menu_items ADD COLUMN IF NOT EXISTS category_id UUID;
ALTER TABLE public.menu_items ADD COLUMN IF NOT EXISTS cost_price NUMERIC DEFAULT 0;
ALTER TABLE public.menu_items ALTER COLUMN cost_price TYPE NUMERIC USING cost_price::NUMERIC;
ALTER TABLE public.menu_items ADD COLUMN IF NOT EXISTS recipe_cost NUMERIC DEFAULT 0;
ALTER TABLE public.menu_items ALTER COLUMN recipe_cost TYPE NUMERIC USING recipe_cost::NUMERIC;
ALTER TABLE public.menu_items ALTER COLUMN price TYPE NUMERIC USING price::NUMERIC;
ALTER TABLE public.menu_items ADD COLUMN IF NOT EXISTS stock_quantity NUMERIC(10,2) DEFAULT 10;
ALTER TABLE public.menu_items ALTER COLUMN stock_quantity TYPE NUMERIC(10,2) USING stock_quantity::NUMERIC;
ALTER TABLE public.menu_item_variants ADD COLUMN IF NOT EXISTS business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE;
ALTER TABLE public.menu_item_variants ADD COLUMN IF NOT EXISTS unit_ratio NUMERIC;
ALTER TABLE public.menu_item_variants ALTER COLUMN price TYPE NUMERIC USING price::NUMERIC;
ALTER TABLE public.menu_items ADD COLUMN IF NOT EXISTS unit TEXT DEFAULT 'Pcs';
ALTER TABLE public.menu_items ADD COLUMN IF NOT EXISTS barcode TEXT;
ALTER TABLE public.menu_items ADD COLUMN IF NOT EXISTS sku TEXT;
ALTER TABLE public.menu_items ADD COLUMN IF NOT EXISTS stock_available BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE public.menu_items ADD COLUMN IF NOT EXISTS track_stock_quantity BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.menu_items ADD COLUMN IF NOT EXISTS is_package BOOLEAN NOT NULL DEFAULT false;

-- Pastikan kolom tabel orders lengkap agar sinkronisasi kasir offline/online selalu mulus
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_email TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS dining_option TEXT DEFAULT 'dine_in';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS kitchen_status TEXT NOT NULL DEFAULT 'pending';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS order_source TEXT NOT NULL DEFAULT 'pos';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS cashier_name TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS waiter_id UUID;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS waiter_name TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS void_reason TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS voided_by UUID;

-- Pastikan tipe data nominal pada orders mendukung numerik pecahan/bulat
ALTER TABLE public.orders ALTER COLUMN subtotal TYPE NUMERIC USING subtotal::NUMERIC;
ALTER TABLE public.orders ALTER COLUMN discount_total TYPE NUMERIC USING discount_total::NUMERIC;
ALTER TABLE public.orders ALTER COLUMN tax_amount TYPE NUMERIC USING tax_amount::NUMERIC;
ALTER TABLE public.orders ALTER COLUMN grand_total TYPE NUMERIC USING grand_total::NUMERIC;
ALTER TABLE public.orders ALTER COLUMN paid_amount TYPE NUMERIC USING paid_amount::NUMERIC;
ALTER TABLE public.orders ALTER COLUMN change_amount TYPE NUMERIC USING change_amount::NUMERIC;

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "orders_all_access" ON public.orders;
CREATE POLICY "orders_all_access" ON public.orders FOR ALL USING (true) WITH CHECK (true);

-- RLS akses penuh untuk menu_items, menu_categories, menu_item_variants, menu_item_tiered_prices, outlets, outlet_members
ALTER TABLE public.menu_categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "menu_categories_all_access" ON public.menu_categories;
CREATE POLICY "menu_categories_all_access" ON public.menu_categories FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "menu_items_all_access" ON public.menu_items;
CREATE POLICY "menu_items_all_access" ON public.menu_items FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.menu_item_variants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "menu_item_variants_all_access" ON public.menu_item_variants;
DROP POLICY IF EXISTS "menu_item_variants_manage_policy" ON public.menu_item_variants;
DROP POLICY IF EXISTS "menu_item_variants_select_policy" ON public.menu_item_variants;
DROP POLICY IF EXISTS "allow_anon_read_menu_variants" ON public.menu_item_variants;
DROP POLICY IF EXISTS "menu_item_variants_select_public" ON public.menu_item_variants;
CREATE POLICY "menu_item_variants_all_access" ON public.menu_item_variants FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.menu_item_tiered_prices ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "menu_item_tiered_prices_all_access" ON public.menu_item_tiered_prices;
DROP POLICY IF EXISTS "menu_item_tiered_prices_manage_policy" ON public.menu_item_tiered_prices;
DROP POLICY IF EXISTS "menu_item_tiered_prices_select_policy" ON public.menu_item_tiered_prices;
CREATE POLICY "menu_item_tiered_prices_all_access" ON public.menu_item_tiered_prices FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.outlets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "outlets_all_access" ON public.outlets;
DROP POLICY IF EXISTS "outlets_select_related" ON public.outlets;
DROP POLICY IF EXISTS "outlets_insert_owner" ON public.outlets;
DROP POLICY IF EXISTS "outlets_update_owner" ON public.outlets;
DROP POLICY IF EXISTS "allow_anon_read_outlets" ON public.outlets;
DROP POLICY IF EXISTS "outlets_select_public" ON public.outlets;
CREATE POLICY "outlets_all_access" ON public.outlets FOR ALL TO authenticated, anon, service_role USING (true) WITH CHECK (true);

ALTER TABLE public.outlet_members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "outlet_members_all_access" ON public.outlet_members;
DROP POLICY IF EXISTS "outlet_members_select_related" ON public.outlet_members;
DROP POLICY IF EXISTS "outlet_members_insert_owner" ON public.outlet_members;
DROP POLICY IF EXISTS "outlet_members_update_owner" ON public.outlet_members;
CREATE POLICY "outlet_members_all_access" ON public.outlet_members FOR ALL TO authenticated, anon, service_role USING (true) WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.is_business_owner(target_business_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.businesses b
    WHERE b.id = target_business_id
      AND b.owner_user_id = auth.uid()
  );
END; $$;
GRANT EXECUTE ON FUNCTION public.is_business_owner(uuid) TO authenticated, anon, service_role;

-- Stored Procedure Auto-heal Outlet Default
CREATE OR REPLACE FUNCTION public.ensure_business_default_outlet(p_business_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_biz record;
  v_outlet_id uuid;
BEGIN
  SELECT * INTO v_biz FROM public.businesses WHERE id = p_business_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bisnis tidak ditemukan');
  END IF;

  SELECT id INTO v_outlet_id FROM public.outlets WHERE business_id = p_business_id LIMIT 1;

  IF v_outlet_id IS NULL THEN
    INSERT INTO public.outlets (
      business_id,
      name,
      code,
      phone,
      address,
      latitude,
      longitude,
      timezone,
      is_active
    )
    VALUES (
      p_business_id,
      COALESCE(v_biz.name, 'Outlet Utama'),
      'main',
      v_biz.phone,
      v_biz.address,
      v_biz.latitude,
      v_biz.longitude,
      'Asia/Jakarta',
      true
    )
    RETURNING id INTO v_outlet_id;
  END IF;

  IF v_biz.owner_user_id IS NOT NULL AND v_outlet_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.outlet_members 
      WHERE outlet_id = v_outlet_id AND user_id = v_biz.owner_user_id
    ) THEN
      INSERT INTO public.outlet_members (outlet_id, user_id, role, status)
      VALUES (v_outlet_id, v_biz.owner_user_id, 'owner', 'active');
    ELSE
      UPDATE public.outlet_members
      SET role = 'owner', status = 'active'
      WHERE outlet_id = v_outlet_id AND user_id = v_biz.owner_user_id;
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'outlet_id', v_outlet_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.ensure_business_default_outlet(uuid) TO authenticated, anon, service_role;

-- 4. RLS UPDATE UNTUK package_fulfillment_orders
DROP POLICY IF EXISTS "Store owners can update their fulfillment orders" ON public.package_fulfillment_orders;
CREATE POLICY "Store owners can update their fulfillment orders"
  ON public.package_fulfillment_orders FOR UPDATE
  TO authenticated, anon, service_role
  USING (true)
  WITH CHECK (true);

-- 5. TABEL DINAMIS: retail_starter_kit_items DENGAN KOLOM CATEGORY
CREATE TABLE IF NOT EXISTS public.retail_starter_kit_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  starter_kit_id UUID NOT NULL REFERENCES public.retail_starter_kits(id) ON DELETE CASCADE,
  master_catalog_id UUID REFERENCES public.master_catalog(id) ON DELETE SET NULL,
  product_name TEXT NOT NULL,
  barcode TEXT,
  quantity INT NOT NULL DEFAULT 1,
  unit TEXT NOT NULL DEFAULT 'Pcs',
  unit_base_price NUMERIC NOT NULL DEFAULT 0,
  unit_selling_price NUMERIC NOT NULL DEFAULT 0,
  category TEXT DEFAULT 'Sembako',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.retail_starter_kit_items ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'Sembako';
CREATE INDEX IF NOT EXISTS idx_rski_starter_kit_id ON public.retail_starter_kit_items(starter_kit_id);
ALTER TABLE public.retail_starter_kit_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "retail_starter_kit_items_read_all" ON public.retail_starter_kit_items;
CREATE POLICY "retail_starter_kit_items_read_all" ON public.retail_starter_kit_items FOR SELECT USING (true);
DROP POLICY IF EXISTS "retail_starter_kit_items_manage_all" ON public.retail_starter_kit_items;
CREATE POLICY "retail_starter_kit_items_manage_all" ON public.retail_starter_kit_items FOR ALL USING (true);

-- Isi otomatis data item per paket jika belum ada
DO $$
DECLARE
  v_kit1 UUID;
  v_kit2 UUID;
  v_kit3 UUID;
  v_kit4 UUID;
BEGIN
  SELECT id INTO v_kit1 FROM public.retail_starter_kits WHERE slug = 'paket-01-toko-pemula' OR sort_order = 1 LIMIT 1;
  SELECT id INTO v_kit2 FROM public.retail_starter_kits WHERE slug = 'paket-02-gen-z-box' OR sort_order = 2 LIMIT 1;
  SELECT id INTO v_kit3 FROM public.retail_starter_kits WHERE slug = 'paket-03-beauty-box' OR sort_order = 3 LIMIT 1;
  SELECT id INTO v_kit4 FROM public.retail_starter_kits WHERE slug = 'paket-04-air-mineral' OR sort_order = 4 LIMIT 1;

  -- Paket 01: Toko Pemula (Sembako & Kebutuhan Harian)
  IF v_kit1 IS NOT NULL THEN
    DELETE FROM public.retail_starter_kit_items WHERE starter_kit_id = v_kit1;
    INSERT INTO public.retail_starter_kit_items (starter_kit_id, product_name, barcode, quantity, unit, unit_base_price, unit_selling_price, category) VALUES
      (v_kit1, 'Beras Premium Syupeo 2 kg', '8999908001001', 2, 'Sak', 28000, 32000, 'Sembako'),
      (v_kit1, 'Minyak Goreng Pouch 1 Liter', '8999908001002', 3, 'Pouch', 14500, 17000, 'Sembako'),
      (v_kit1, 'Gula Pasir Kristal 1 kg', '8999908001003', 2, 'Bks', 14000, 16500, 'Sembako'),
      (v_kit1, 'Tepung Terigu Serbaguna 1 kg', '8999908001004', 2, 'Bks', 10500, 12500, 'Sembako'),
      (v_kit1, 'Indomie Mi Goreng Spesial 85g', '8998866200225', 10, 'Pcs', 2800, 3500, 'Makanan Instan'),
      (v_kit1, 'Kopi Kapal Api Spesial Mix (Renceng)', '8999908002001', 2, 'Renceng', 11500, 14000, 'Minuman'),
      (v_kit1, 'Teh Celup Pilihan (Dus isi 25)', '899100100007', 2, 'Kotak', 5500, 7500, 'Minuman'),
      (v_kit1, 'Sabun Mandi Keluarga (Pack isi 4)', '899100100008', 2, 'Pack', 12000, 15000, 'Kebutuhan Rumah'),
      (v_kit1, 'Sabun Cuci Piring Cair 400ml', '899100100009', 2, 'Pouch', 4500, 6500, 'Kebutuhan Rumah'),
      (v_kit1, 'Deterjen Pakaian Bersih 800g', '899100100010', 2, 'Bks', 15000, 19000, 'Kebutuhan Rumah'),
      (v_kit1, 'Pasta Gigi Herbal 120g', '899100100011', 2, 'Tube', 8500, 11500, 'Kebutuhan Rumah'),
      (v_kit1, 'Kecap Manis Botol Sedap', '899100100012', 2, 'Botol', 7500, 10000, 'Sembako');
  END IF;

  -- Paket 02: Gen Z Box
  IF v_kit2 IS NOT NULL THEN
    DELETE FROM public.retail_starter_kit_items WHERE starter_kit_id = v_kit2;
    INSERT INTO public.retail_starter_kit_items (starter_kit_id, product_name, barcode, quantity, unit, unit_base_price, unit_selling_price, category) VALUES
      (v_kit2, 'Phone Charm Manik Viral', '8999908005001', 6, 'Pcs', 6500, 12000, 'Aksesori Gen Z'),
      (v_kit2, 'Pop Socket Karakter 3D Hologram', '8999908005002', 6, 'Pcs', 4500, 10000, 'Aksesori Gen Z'),
      (v_kit2, 'Scrunchie Ikat Rambut Silk Korea', '8999908005003', 8, 'Pcs', 3000, 7000, 'Aksesori Gen Z'),
      (v_kit2, 'Pelindung Kabel Handphone Spiral', '8999908005004', 8, 'Pcs', 2500, 5000, 'Aksesori Gen Z'),
      (v_kit2, 'Gantungan Kunci Estetik Akrilik', '8999908005005', 6, 'Pcs', 4000, 8000, 'Aksesori Gen Z'),
      (v_kit2, 'Kaos Kaki Korea Stylish', '8999908005006', 5, 'Pasang', 6000, 12000, 'Aksesori Gen Z'),
      (v_kit2, 'Mini Pouch Cantik Serbaguna', '8999908005007', 4, 'Pcs', 8000, 15000, 'Aksesori Gen Z');
  END IF;

  -- Paket 03: Beauty Box Makarizo
  IF v_kit3 IS NOT NULL THEN
    DELETE FROM public.retail_starter_kit_items WHERE starter_kit_id = v_kit3;
    INSERT INTO public.retail_starter_kit_items (starter_kit_id, product_name, barcode, quantity, unit, unit_base_price, unit_selling_price, category) VALUES
      (v_kit3, 'Makarizo Hair Energy Creambath Aloe 60g', '8999908004001', 5, 'Pouch', 12500, 16000, 'Beauty & Perawatan'),
      (v_kit3, 'Makarizo Advisor Hair Recovery Serum 8ml', '8999908004002', 6, 'Tube', 8000, 11000, 'Beauty & Perawatan'),
      (v_kit3, 'Makarizo Hair Energy Creambath Kiwi 60g', '8999908004003', 4, 'Pouch', 12500, 16000, 'Beauty & Perawatan'),
      (v_kit3, 'Makarizo Hair Energy Creambath Royal Jelly 60g', '8999908004004', 4, 'Pouch', 12500, 16000, 'Beauty & Perawatan');
  END IF;

  -- Paket 04: Air Mineral
  IF v_kit4 IS NOT NULL THEN
    DELETE FROM public.retail_starter_kit_items WHERE starter_kit_id = v_kit4;
    INSERT INTO public.retail_starter_kit_items (starter_kit_id, product_name, barcode, quantity, unit, unit_base_price, unit_selling_price, category) VALUES
      (v_kit4, 'Air Mineral VICA 600 mL (Tutup Kuning)', '8999908003001', 24, 'Botol', 3500, 5000, 'Air Mineral'),
      (v_kit4, 'Air Minum Galon Nestlé Pure Life 19L', '8999908003003', 2, 'Galon', 22000, 26000, 'Air Mineral'),
      (v_kit4, 'Air Mineral VICA 330 mL Mini Botol', '8999908003004', 24, 'Botol', 2500, 3500, 'Air Mineral');
  END IF;
END $$;

-- 6. STORED PROCEDURE 100% DINAMIS: apply_starter_kit_to_business
-- Mengenerate kategori secara otomatis sesuai master produk (Sembako, Minuman, Makanan Instan, dll)
CREATE OR REPLACE FUNCTION public.apply_starter_kit_to_business(
  p_business_id UUID,
  p_starter_kit_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_kit_id UUID := p_starter_kit_id;
  v_item RECORD;
  v_cat_name TEXT;
  v_cat_id UUID;
  v_visual_idx INT := 0;
  v_inserted_count INT := 0;
BEGIN
  -- 1. Cari starter kit jika belum di-passing
  IF v_kit_id IS NULL THEN
    SELECT starter_kit_id INTO v_kit_id FROM public.businesses WHERE id = p_business_id;
  END IF;

  IF v_kit_id IS NULL THEN
    SELECT id INTO v_kit_id FROM public.retail_starter_kits WHERE is_active = true ORDER BY sort_order LIMIT 1;
  END IF;

  IF v_kit_id IS NULL THEN
    SELECT id INTO v_kit_id FROM public.retail_starter_kits ORDER BY created_at ASC LIMIT 1;
  END IF;

  -- 2. Loop setiap item dari retail_starter_kit_items (dengan fallback master_catalog)
  FOR v_item IN (
    SELECT 
      rski.product_name,
      rski.barcode,
      rski.quantity,
      rski.unit,
      rski.unit_base_price,
      rski.unit_selling_price,
      COALESCE(rski.category, mc.category, 'Sembako') AS category
    FROM public.retail_starter_kit_items rski
    LEFT JOIN public.master_catalog mc ON mc.barcode = rski.barcode OR lower(btrim(mc.name)) = lower(btrim(rski.product_name))
    WHERE rski.starter_kit_id = v_kit_id
  ) LOOP
    v_cat_name := initcap(btrim(v_item.category));
    IF v_cat_name IS NULL OR v_cat_name = '' THEN
      v_cat_name := 'Sembako';
    END IF;

    -- Dapatkan atau buat menu_categories spesifik untuk kategori ini
    SELECT id INTO v_cat_id
    FROM public.menu_categories
    WHERE business_id = p_business_id
      AND lower(btrim(name)) = lower(btrim(v_cat_name))
    LIMIT 1;

    IF v_cat_id IS NULL THEN
      SELECT COALESCE(MAX(visual_index), 0) + 1 INTO v_visual_idx
      FROM public.menu_categories
      WHERE business_id = p_business_id;

      INSERT INTO public.menu_categories (business_id, name, visual_index)
      VALUES (p_business_id, v_cat_name, COALESCE(v_visual_idx, 0))
      RETURNING id INTO v_cat_id;
    END IF;

    -- Masukkan atau perbarui menu_items dengan category_id yang benar
    IF NOT EXISTS (
      SELECT 1 FROM public.menu_items
      WHERE business_id = p_business_id
        AND lower(btrim(name)) = lower(btrim(v_item.product_name))
    ) THEN
      INSERT INTO public.menu_items (
        business_id, category_id, name, price, cost_price, recipe_cost,
        stock_quantity, unit, barcode, stock_available, track_stock_quantity
      ) VALUES (
        p_business_id, v_cat_id, v_item.product_name, v_item.unit_selling_price, v_item.unit_base_price, v_item.unit_base_price,
        v_item.quantity, v_item.unit, v_item.barcode, true, true
      );
      v_inserted_count := v_inserted_count + 1;
    ELSE
      -- Jika produk sudah ada, sinkronkan kategori, kuantitas stok fisik riil, dan aktifkan pelacakan stok wajib
      UPDATE public.menu_items
      SET 
        category_id = v_cat_id,
        stock_quantity = v_item.quantity,
        unit = COALESCE(nullif(unit, ''), v_item.unit),
        barcode = COALESCE(barcode, v_item.barcode),
        stock_available = true,
        track_stock_quantity = true
      WHERE business_id = p_business_id
        AND lower(btrim(name)) = lower(btrim(v_item.product_name));
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'business_id', p_business_id,
    'starter_kit_id', v_kit_id,
    'items_added', v_inserted_count
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.apply_starter_kit_to_business(UUID, UUID) TO authenticated, service_role, anon;

-- 7. STORED PROCEDURE: confirm_starter_kit_delivery
CREATE OR REPLACE FUNCTION public.confirm_starter_kit_delivery(
  p_order_id UUID,
  p_business_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order RECORD;
  v_biz_id UUID := p_business_id;
  v_kit_id UUID;
  v_res JSONB;
BEGIN
  -- 1. Ambil data order fulfillment
  SELECT * INTO v_order FROM public.package_fulfillment_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Pesanan pengiriman tidak ditemukan');
  END IF;

  -- 2. Update status order menjadi 'delivered' & set delivered_at
  UPDATE public.package_fulfillment_orders
  SET 
    status = 'delivered',
    delivered_at = COALESCE(delivered_at, NOW())
  WHERE id = p_order_id;

  -- 3. Cari business_id jika belum di-passing
  IF v_biz_id IS NULL THEN
    SELECT b.id INTO v_biz_id
    FROM public.businesses b
    WHERE b.owner_user_id = auth.uid()
    LIMIT 1;
  END IF;

  IF v_biz_id IS NULL AND v_order.recipient_phone IS NOT NULL THEN
    SELECT b.id INTO v_biz_id
    FROM public.businesses b
    WHERE regexp_replace(b.phone, '\D', '', 'g') = regexp_replace(v_order.recipient_phone, '\D', '', 'g')
       OR b.phone = v_order.recipient_phone
    LIMIT 1;
  END IF;

  IF v_biz_id IS NULL THEN
    SELECT b.id INTO v_biz_id
    FROM public.businesses b
    ORDER BY b.created_at DESC
    LIMIT 1;
  END IF;

  v_kit_id := v_order.starter_kit_id;

  -- 4. Aktifkan bisnis dan panggil apply_starter_kit_to_business
  IF v_biz_id IS NOT NULL THEN
    UPDATE public.businesses
    SET status = 'active'
    WHERE id = v_biz_id;

    IF v_kit_id IS NULL THEN
      SELECT starter_kit_id INTO v_kit_id FROM public.businesses WHERE id = v_biz_id;
    END IF;

    v_res := public.apply_starter_kit_to_business(v_biz_id, v_kit_id);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'status', 'delivered',
    'business_id', v_biz_id,
    'apply_result', v_res,
    'message', 'Paket berhasil dikonfirmasi diterima dan produk starter kit siap di kasir POS!'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirm_starter_kit_delivery(UUID, UUID) TO authenticated, service_role, anon;

-- 8. EKSEKUSI SINKRONISASI SEKARANG JUGA:
-- A. Pastikan visual_index menu_categories tidak null
UPDATE public.menu_categories SET visual_index = 0 WHERE visual_index IS NULL;

-- B. Jalankan apply_starter_kit_to_business untuk seluruh bisnis agar produk langsung memiliki kategori resmi
DO $$
DECLARE
  b RECORD;
  v_default_kit_id UUID;
BEGIN
  SELECT id INTO v_default_kit_id FROM public.retail_starter_kits ORDER BY sort_order LIMIT 1;

  FOR b IN SELECT id, name, starter_kit_id FROM public.businesses LOOP
    UPDATE public.businesses SET status = 'active' WHERE id = b.id AND status != 'active';
    PERFORM public.ensure_business_default_outlet(b.id);
    PERFORM public.apply_starter_kit_to_business(b.id, COALESCE(b.starter_kit_id, v_default_kit_id));

    -- C. Pastikan produk yang sudah ada di toko langsung terhubung ke kategori yang tepat (hilangkan status "TANPA KATEGORI")
    -- Hubungkan Sembako
    UPDATE public.menu_items mi
    SET category_id = (
      SELECT mc.id FROM public.menu_categories mc 
      WHERE mc.business_id = b.id AND lower(btrim(mc.name)) = 'sembako' 
      LIMIT 1
    )
    WHERE mi.business_id = b.id 
      AND mi.category_id IS NULL
      AND (
        lower(mi.name) LIKE '%beras%' OR 
        lower(mi.name) LIKE '%minyak%' OR 
        lower(mi.name) LIKE '%gula%' OR 
        lower(mi.name) LIKE '%tepung%' OR 
        lower(mi.name) LIKE '%kecap%'
      );

    -- Hubungkan Makanan Instan
    UPDATE public.menu_items mi
    SET category_id = (
      SELECT mc.id FROM public.menu_categories mc 
      WHERE mc.business_id = b.id AND lower(btrim(mc.name)) = 'makanan instan' 
      LIMIT 1
    )
    WHERE mi.business_id = b.id 
      AND mi.category_id IS NULL
      AND (lower(mi.name) LIKE '%indomie%' OR lower(mi.name) LIKE '%mie%');

    -- Hubungkan Minuman
    UPDATE public.menu_items mi
    SET category_id = (
      SELECT mc.id FROM public.menu_categories mc 
      WHERE mc.business_id = b.id AND lower(btrim(mc.name)) = 'minuman' 
      LIMIT 1
    )
    WHERE mi.business_id = b.id 
      AND mi.category_id IS NULL
      AND (lower(mi.name) LIKE '%kopi%' OR lower(mi.name) LIKE '%teh%');

    -- Hubungkan Kebutuhan Rumah
    UPDATE public.menu_items mi
    SET category_id = (
      SELECT mc.id FROM public.menu_categories mc 
      WHERE mc.business_id = b.id AND lower(btrim(mc.name)) = 'kebutuhan rumah' 
      LIMIT 1
    )
    WHERE mi.business_id = b.id 
      AND mi.category_id IS NULL
      AND (
        lower(mi.name) LIKE '%sabun%' OR 
        lower(mi.name) LIKE '%deterjen%' OR 
        lower(mi.name) LIKE '%pasta gigi%'
      );

    -- Fallback: produk apa saja yang masih belum punya kategori diarahkan ke kategori pertama toko
    UPDATE public.menu_items mi
    SET category_id = (
      SELECT mc.id FROM public.menu_categories mc 
      WHERE mc.business_id = b.id 
      ORDER BY mc.visual_index ASC 
      LIMIT 1
    )
    WHERE mi.business_id = b.id AND mi.category_id IS NULL;

    -- D. WAJIB: Aktifkan batasan stok fisik (track_stock_quantity = true) dan sinkronkan kuantitas fisik starter kit
    UPDATE public.menu_items mi
    SET 
      track_stock_quantity = true,
      stock_available = true,
      stock_quantity = COALESCE(
        (SELECT rski.quantity FROM public.retail_starter_kit_items rski 
         WHERE lower(btrim(rski.product_name)) = lower(btrim(mi.name)) LIMIT 1),
        CASE 
          WHEN lower(mi.name) LIKE '%beras%' THEN 2
          WHEN lower(mi.name) LIKE '%minyak%' THEN 3
          WHEN lower(mi.name) LIKE '%gula%' THEN 2
          WHEN lower(mi.name) LIKE '%tepung%' THEN 2
          WHEN lower(mi.name) LIKE '%indomie%' THEN 10
          WHEN lower(mi.name) LIKE '%kopi%' THEN 2
          WHEN lower(mi.name) LIKE '%teh%' THEN 2
          WHEN lower(mi.name) LIKE '%sabun mandi%' THEN 2
          WHEN lower(mi.name) LIKE '%cuci piring%' THEN 2
          WHEN lower(mi.name) LIKE '%deterjen%' THEN 2
          WHEN lower(mi.name) LIKE '%pasta gigi%' THEN 2
          WHEN lower(mi.name) LIKE '%kecap%' THEN 2
          WHEN lower(mi.name) LIKE '%vica 600%' THEN 24
          WHEN lower(mi.name) LIKE '%galon%' THEN 2
          WHEN lower(mi.name) LIKE '%vica 330%' THEN 24
          ELSE COALESCE(nullif(mi.stock_quantity, 0), 10)
        END
      )
    WHERE mi.business_id = b.id;
  END LOOP;
END $$;

-- 9. TABEL & DATA: outlet_payment_methods (Mencegah PGRST205 di Pengaturan & Kasir)
CREATE TABLE IF NOT EXISTS public.outlet_payment_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'cash',
  provider TEXT,
  account_label TEXT,
  account_number TEXT,
  instructions TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INT NOT NULL DEFAULT 0,
  requires_reference BOOLEAN NOT NULL DEFAULT false,
  allows_change BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- Pastikan unique index ada agar integritas data terjamin
CREATE UNIQUE INDEX IF NOT EXISTS outlet_payment_methods_outlet_code_unique_idx
ON public.outlet_payment_methods (outlet_id, code);

ALTER TABLE public.outlet_payment_methods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "outlet_payment_methods_select" ON public.outlet_payment_methods;
CREATE POLICY "outlet_payment_methods_select" ON public.outlet_payment_methods
  FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "outlet_payment_methods_all" ON public.outlet_payment_methods;
CREATE POLICY "outlet_payment_methods_all" ON public.outlet_payment_methods
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Otomatis masukkan metode default (Tunai, QRIS, Transfer) menggunakan WHERE NOT EXISTS
-- (100% aman, tidak akan memicu error 42P10 ON CONFLICT)
INSERT INTO public.outlet_payment_methods (outlet_id, code, name, type, is_active, sort_order, allows_change)
SELECT o.id, 'cash', 'Tunai', 'cash', true, 0, true
FROM public.outlets o
WHERE NOT EXISTS (
  SELECT 1 FROM public.outlet_payment_methods opm 
  WHERE opm.outlet_id = o.id AND opm.code = 'cash'
);

INSERT INTO public.outlet_payment_methods (outlet_id, code, name, type, is_active, sort_order, allows_change)
SELECT o.id, 'qris', 'QRIS', 'qris', true, 1, false
FROM public.outlets o
WHERE NOT EXISTS (
  SELECT 1 FROM public.outlet_payment_methods opm 
  WHERE opm.outlet_id = o.id AND opm.code = 'qris'
);

INSERT INTO public.outlet_payment_methods (outlet_id, code, name, type, is_active, sort_order, allows_change)
SELECT o.id, 'bank_transfer', 'Transfer Bank', 'bank_transfer', true, 2, false
FROM public.outlets o
WHERE NOT EXISTS (
  SELECT 1 FROM public.outlet_payment_methods opm 
  WHERE opm.outlet_id = o.id AND opm.code = 'bank_transfer'
);

-- 10. Refresh schema cache PostgREST Supabase
-- 10. RPC adjust_menu_item_stock yang mendukung desimal / fraksi (Opsi 1: Multiplier 1/2 kg, 1/4 kg)
CREATE OR REPLACE FUNCTION public.adjust_menu_item_stock(
  target_menu_item_id UUID,
  target_outlet_id UUID,
  target_new_quantity NUMERIC,
  target_note TEXT DEFAULT NULL,
  target_reference_type TEXT DEFAULT 'manual_adjustment'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_biz_id UUID;
BEGIN
  SELECT business_id INTO v_biz_id
  FROM public.menu_items
  WHERE id = target_menu_item_id;

  IF v_biz_id IS NULL THEN
    RAISE EXCEPTION 'Produk tidak ditemukan.';
  END IF;

  UPDATE public.menu_items
  SET stock_quantity = target_new_quantity,
      stock_available = (target_new_quantity > 0),
      updated_at = timezone('utc', now())
  WHERE id = target_menu_item_id;

  RETURN target_menu_item_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.adjust_menu_item_stock(UUID, UUID, NUMERIC, TEXT, TEXT) TO authenticated, service_role, anon;

-- 11. Refresh schema cache PostgREST Supabase
NOTIFY pgrst, 'reload schema';
