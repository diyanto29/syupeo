-- ==============================================================================
-- SYUPEO DATABASE MIGRATION SYSTEM
-- Migration: 20261030110000_create_warehouses_and_fulfillment_dispatch.sql
-- Description: Membuat struktur Multi-Node Warehouses (Hub Syupeo vs Agen Pabrik Cleo/Unilever)
--              dan sistem Order Dispatch & Tracking Pengiriman Paket Usaha White-label
-- ==============================================================================

-- 1. Pastikan tabel warehouses memiliki kolom lengkap untuk multi-node fulfillment
CREATE TABLE IF NOT EXISTS public.warehouses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(50) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  warehouse_type VARCHAR(50) NOT NULL DEFAULT 'syupeo_hub', -- 'syupeo_hub', 'principal_agent', 'third_party_3pl'
  brand_partner VARCHAR(255),                                -- 'Cleo', 'Unilever', 'Makarizo', 'Syupeo Internal'
  address TEXT NOT NULL,
  city VARCHAR(100) NOT NULL,
  province VARCHAR(100),
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  coverage_radius_km NUMERIC(5,2) DEFAULT 25.0,
  pic_name VARCHAR(100) NOT NULL,
  pic_phone VARCHAR(50) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Pastikan kolom baru ada jika tabel sudah pernah dibuat sebelumnya
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'warehouses' AND column_name = 'warehouse_type') THEN
    ALTER TABLE public.warehouses ADD COLUMN warehouse_type VARCHAR(50) NOT NULL DEFAULT 'syupeo_hub';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'warehouses' AND column_name = 'brand_partner') THEN
    ALTER TABLE public.warehouses ADD COLUMN brand_partner VARCHAR(255);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'warehouses' AND column_name = 'code') THEN
    ALTER TABLE public.warehouses ADD COLUMN code VARCHAR(50);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'warehouses' AND column_name = 'city') THEN
    ALTER TABLE public.warehouses ADD COLUMN city VARCHAR(100) DEFAULT 'Indonesia';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'warehouses' AND column_name = 'province') THEN
    ALTER TABLE public.warehouses ADD COLUMN province VARCHAR(100);
  END IF;
END $$;

-- Index performa pencarian gudang
CREATE INDEX IF NOT EXISTS idx_warehouses_active ON public.warehouses(is_active);
CREATE INDEX IF NOT EXISTS idx_warehouses_type ON public.warehouses(warehouse_type);
CREATE INDEX IF NOT EXISTS idx_warehouses_city ON public.warehouses(city);

-- RLS untuk tabel warehouses
ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view active warehouses" ON public.warehouses;
CREATE POLICY "Anyone can view active warehouses"
  ON public.warehouses FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins can manage warehouses" ON public.warehouses;
CREATE POLICY "Admins can manage warehouses"
  ON public.warehouses FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_users
      WHERE email = lower(auth.jwt() ->> 'email') AND is_active = true
    ) OR (lower(auth.jwt() ->> 'email') = 'diyanto2911@gmail.com')
  );

-- 2. Buat tabel package_fulfillment_orders (Order Dispatch Pengiriman Paket Usaha)
CREATE TABLE IF NOT EXISTS public.package_fulfillment_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_code VARCHAR(100) UNIQUE NOT NULL,
  starter_kit_id UUID REFERENCES public.retail_starter_kits(id) ON DELETE SET NULL,
  kit_name VARCHAR(255) NOT NULL,
  recipient_name VARCHAR(255) NOT NULL,
  recipient_phone VARCHAR(50) NOT NULL,
  shipping_address TEXT NOT NULL,
  shipping_city VARCHAR(100) NOT NULL,
  recipient_lat DOUBLE PRECISION,
  recipient_lng DOUBLE PRECISION,
  fulfillment_mode VARCHAR(50) NOT NULL DEFAULT 'agent_direct', -- 'agent_direct' vs 'syupeo_central'
  assigned_warehouse_id UUID REFERENCES public.warehouses(id) ON DELETE SET NULL,
  sender_alias VARCHAR(255) NOT NULL DEFAULT 'SYUPEO OFFICIAL',
  distance_km NUMERIC(6,2),
  status VARCHAR(50) NOT NULL DEFAULT 'pending_dispatch', -- 'pending_dispatch', 'packing', 'in_transit', 'delivered', 'cancelled'
  driver_name VARCHAR(100),
  driver_phone VARCHAR(50),
  tracking_number VARCHAR(100),
  dispatched_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  proof_image_url TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Index performa order dispatch
CREATE INDEX IF NOT EXISTS idx_pfo_status ON public.package_fulfillment_orders(status);
CREATE INDEX IF NOT EXISTS idx_pfo_warehouse ON public.package_fulfillment_orders(assigned_warehouse_id);

-- RLS untuk tabel package_fulfillment_orders
ALTER TABLE public.package_fulfillment_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view fulfillment orders" ON public.package_fulfillment_orders;
CREATE POLICY "Anyone can view fulfillment orders"
  ON public.package_fulfillment_orders FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins can manage fulfillment orders" ON public.package_fulfillment_orders;
CREATE POLICY "Admins can manage fulfillment orders"
  ON public.package_fulfillment_orders FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_users
      WHERE email = lower(auth.jwt() ->> 'email') AND is_active = true
    ) OR (lower(auth.jwt() ->> 'email') = 'diyanto2911@gmail.com')
  );

-- 3. SEED JARINGAN GUDANG STRATEGIS SYUPEO (Pusat & Agen Pabrik)
INSERT INTO public.warehouses (code, name, warehouse_type, brand_partner, address, city, province, latitude, longitude, coverage_radius_km, pic_name, pic_phone, is_active)
VALUES
  (
    'WH-HQ-JKT',
    'Hub Pusat Syupeo Jakarta (Packing & Assembly)',
    'syupeo_hub',
    'Syupeo Internal',
    'Jl. TB Simatupang No. 88, Cilandak',
    'Jakarta Selatan',
    'DKI Jakarta',
    -6.2915,
    106.8186,
    40.0,
    'Bambang Supriyanto',
    '0812-8899-7711',
    TRUE
  ),
  (
    'WH-CLEO-SBY',
    'Depo Cleo Surabaya Rungkut (Distributor Resmi)',
    'principal_agent',
    'Cleo (PT Sariguna Primatirta)',
    'Kawasan Industri Rungkut Megah Raya Blok B-12',
    'Surabaya',
    'Jawa Timur',
    -7.3188,
    112.7663,
    30.0,
    'Agus Salim (Spv Cleo)',
    '0813-3344-5566',
    TRUE
  ),
  (
    'WH-UNVR-BDG',
    'Distributor Agen Unilever Bandung Soekarno Hatta',
    'principal_agent',
    'Unilever Indonesia',
    'Jl. Soekarno Hatta No. 452, Batununggal',
    'Bandung',
    'Jawa Barat',
    -6.9452,
    107.6385,
    25.0,
    'Hendra Gunawan',
    '0821-2233-4455',
    TRUE
  ),
  (
    'WH-MKRZ-SMG',
    'Depo Distribusi Makarizo & Kosmetik Semarang',
    'principal_agent',
    'Makarizo Indonesia',
    'Jl. Brigjen Sudiarto No. 210, Gayamsari',
    'Semarang',
    'Jawa Tengah',
    -6.9932,
    110.4501,
    25.0,
    'Rina Kartika',
    '0857-1122-3344',
    TRUE
  )
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  warehouse_type = EXCLUDED.warehouse_type,
  brand_partner = EXCLUDED.brand_partner,
  address = EXCLUDED.address,
  city = EXCLUDED.city,
  province = EXCLUDED.province,
  pic_name = EXCLUDED.pic_name,
  pic_phone = EXCLUDED.pic_phone;

-- 4. SEED SAMPLE ACTIVE DISPATCH ORDERS
INSERT INTO public.package_fulfillment_orders (
  order_code,
  kit_name,
  recipient_name,
  recipient_phone,
  shipping_address,
  shipping_city,
  recipient_lat,
  recipient_lng,
  fulfillment_mode,
  assigned_warehouse_id,
  sender_alias,
  distance_km,
  status,
  driver_name,
  driver_phone,
  notes
)
SELECT 
  'SYP-202610-001',
  'Paket 04 — Air Mineral (VICA + Pure Life)',
  'Ibu Hj. Aminah (Warung Barokah)',
  '0812-3456-7891',
  'Jl. Manyar Sabrangan No. 14, Sukolilo',
  'Surabaya',
  -7.2891,
  112.7725,
  'agent_direct',
  w.id,
  'SYUPEO OFFICIAL (c/o Depo Cleo Surabaya)',
  4.8,
  'in_transit',
  'Pak Joko (Armada Pick-up Cleo)',
  '0819-8765-4321',
  'Kirim 1 karton VICA + 1 Galon Pure Life. Disertai banner toko retail Syupeo.'
FROM public.warehouses w WHERE w.code = 'WH-CLEO-SBY'
ON CONFLICT (order_code) DO NOTHING;

INSERT INTO public.package_fulfillment_orders (
  order_code,
  kit_name,
  recipient_name,
  recipient_phone,
  shipping_address,
  shipping_city,
  recipient_lat,
  recipient_lng,
  fulfillment_mode,
  assigned_warehouse_id,
  sender_alias,
  distance_km,
  status,
  driver_name,
  driver_phone,
  notes
)
SELECT 
  'SYP-202610-002',
  'Paket 01 — Toko Pemula (Sembako & Kebutuhan Harian)',
  'Bpk. Ridwan Fauzi (Toko Berkah Mandiri)',
  '0856-7890-1234',
  'Jl. Buah Batu No. 128, Lengkong',
  'Bandung',
  -6.9385,
  107.6250,
  'agent_direct',
  w.id,
  'SYUPEO OFFICIAL (c/o Distributor Unilever Bandung)',
  3.2,
  'packing',
  NULL,
  NULL,
  'Siapkan paket sembako lengkap beras, minyak, sabun, deterjen.'
FROM public.warehouses w WHERE w.code = 'WH-UNVR-BDG'
ON CONFLICT (order_code) DO NOTHING;

-- 5. Catat migrasi
INSERT INTO public._syupeo_migrations (version, name, description)
VALUES (
  '20261030110000',
  'create_warehouses_and_fulfillment_dispatch',
  'Struktur Multi-Node Warehouses (Hub Syupeo vs Agen Pabrik Cleo/Unilever) dan Order Dispatch Tracking'
)
ON CONFLICT (version) DO UPDATE SET
  applied_at = timezone('utc'::text, now()),
  description = EXCLUDED.description;

