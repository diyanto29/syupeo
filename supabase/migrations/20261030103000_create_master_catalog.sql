-- ==============================================================================
-- SYUPEO DATABASE MIGRATION SYSTEM
-- Migration: 20261030103000_create_master_catalog.sql
-- Description: Membuat tabel master_catalog (Katalog Barcode Nasional Syupeo),
--              index pg_trgm untuk pencarian cepat, kebijakan RLS, dan seed produk awal.
-- ==============================================================================

-- Pastikan extension pg_trgm aktif untuk fuzzy / autocomplete search produk
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 1. Buat tabel master_catalog jika belum ada
CREATE TABLE IF NOT EXISTS public.master_catalog (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  barcode TEXT UNIQUE,
  name TEXT NOT NULL,
  category TEXT DEFAULT 'UMUM',
  brand TEXT,
  base_price NUMERIC DEFAULT 0,    -- Harga Modal / Grosir Pabrik
  selling_price NUMERIC DEFAULT 0, -- Harga Eceran Tertinggi (HET) / Rekomendasi
  unit TEXT DEFAULT 'Pcs',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. Index performa pencarian barcode dan teks produk
CREATE INDEX IF NOT EXISTS idx_master_catalog_barcode ON public.master_catalog(barcode);
CREATE INDEX IF NOT EXISTS idx_master_catalog_category ON public.master_catalog(category);
CREATE INDEX IF NOT EXISTS idx_master_catalog_name_trgm ON public.master_catalog USING gin(name gin_trgm_ops);

-- 3. Aktifkan Row Level Security (RLS)
ALTER TABLE public.master_catalog ENABLE ROW LEVEL SECURITY;

-- Policy: Publik / Semua pengguna terautentikasi dapat membaca katalog produk
DROP POLICY IF EXISTS "Anyone can view master catalog" ON public.master_catalog;
CREATE POLICY "Anyone can view master catalog"
  ON public.master_catalog
  FOR SELECT
  USING (true);

-- Policy: Hanya Admin yang dapat menambah, mengubah, dan menghapus produk master
DROP POLICY IF EXISTS "Admins can insert master catalog" ON public.master_catalog;
CREATE POLICY "Admins can insert master catalog"
  ON public.master_catalog
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.admin_users
      WHERE email = lower(auth.jwt() ->> 'email')
        AND is_active = true
    ) OR (lower(auth.jwt() ->> 'email') = 'diyanto2911@gmail.com')
  );

DROP POLICY IF EXISTS "Admins can update master catalog" ON public.master_catalog;
CREATE POLICY "Admins can update master catalog"
  ON public.master_catalog
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_users
      WHERE email = lower(auth.jwt() ->> 'email')
        AND is_active = true
    ) OR (lower(auth.jwt() ->> 'email') = 'diyanto2911@gmail.com')
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.admin_users
      WHERE email = lower(auth.jwt() ->> 'email')
        AND is_active = true
    ) OR (lower(auth.jwt() ->> 'email') = 'diyanto2911@gmail.com')
  );

DROP POLICY IF EXISTS "Admins can delete master catalog" ON public.master_catalog;
CREATE POLICY "Admins can delete master catalog"
  ON public.master_catalog
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_users
      WHERE email = lower(auth.jwt() ->> 'email')
        AND is_active = true
    ) OR (lower(auth.jwt() ->> 'email') = 'diyanto2911@gmail.com')
  );

-- 4. Seed Produk Awal Resmi Syupeo (Item dari 4 Starter Kit & Kebutuhan Harian)
INSERT INTO public.master_catalog (barcode, name, category, brand, base_price, selling_price, unit)
VALUES
  ('8999908001001', 'Beras Premium Syupeo 2 kg', 'SEMBAKO', 'Syupeo Rice', 28000, 32000, 'Sak'),
  ('8999908001002', 'Minyak Goreng Pouch 1 Liter', 'SEMBAKO', 'Syupeo Mart', 14500, 17000, 'Pouch'),
  ('8999908001003', 'Gula Pasir Kristal Putih 1 kg', 'SEMBAKO', 'Gulaku', 14000, 16500, 'Bks'),
  ('8999908001004', 'Tepung Terigu Segitiga Biru 1 kg', 'SEMBAKO', 'Bogasari', 10500, 12500, 'Bks'),
  ('8998866200225', 'Indomie Mi Goreng Spesial 85g', 'MAKANAN INSTAN', 'Indomie', 2800, 3500, 'Pcs'),
  ('8999908002001', 'Kopi Kapal Api Spesial Mix 10x24g', 'MINUMAN', 'Kapal Api', 11500, 14000, 'Renceng'),
  ('8999908003001', 'Air Mineral VICA 600 mL (Tutup Kuning)', 'AIR MINERAL', 'VICA', 3500, 5000, 'Botol'),
  ('8999908003002', 'Air Mineral VICA 600 mL Karton (24 Botol)', 'AIR MINERAL', 'VICA', 75000, 84000, 'Karton'),
  ('8999908003003', 'Air Minum Galon Nestlé Pure Life 19L', 'AIR MINERAL', 'Nestle Pure Life', 22000, 26000, 'Galon'),
  ('8999908004001', 'Makarizo Hair Energy Creambath Aloe 60g', 'BEAUTY & PERAWATAN', 'Makarizo', 12500, 16000, 'Pouch'),
  ('8999908004002', 'Makarizo Advisor Hair Recovery Serum 8ml', 'BEAUTY & PERAWATAN', 'Makarizo', 8000, 11000, 'Tube'),
  ('8999908005001', 'Phone Charm Aksesori Manik Viral', 'AKSESORI GEN Z', 'Syupeo Style', 6500, 12000, 'Pcs'),
  ('8999908005002', 'Pop Socket Karakter 3D Hologram', 'AKSESORI GEN Z', 'Syupeo Style', 4500, 10000, 'Pcs'),
  ('8999908005003', 'Scrunchie Ikat Rambut Silk Korea', 'AKSESORI GEN Z', 'Syupeo Style', 3000, 7000, 'Pcs')
ON CONFLICT (barcode) DO UPDATE SET
  name = EXCLUDED.name,
  category = EXCLUDED.category,
  brand = EXCLUDED.brand,
  base_price = EXCLUDED.base_price,
  selling_price = EXCLUDED.selling_price,
  unit = EXCLUDED.unit;

-- 5. Catat migrasi ke tabel registri audit
INSERT INTO public._syupeo_migrations (version, name, description)
VALUES (
  '20261030103000',
  'create_master_catalog',
  'Membuat tabel master_catalog (Katalog Barcode Nasional), index pg_trgm, RLS dan seed produk retail'
)
ON CONFLICT (version) DO UPDATE SET
  applied_at = timezone('utc'::text, now()),
  description = EXCLUDED.description;

