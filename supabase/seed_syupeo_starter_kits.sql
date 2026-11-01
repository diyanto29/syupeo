-- ==============================================================================
-- SYUPEO RETAIL STARTER KITS SEED SCRIPT
-- Menambahkan 4 Paket Usaha Awal (@ Rp 200.000) Resmi ke Database Supabase
-- Tabel: public.retail_starter_kits (Bukan hardware_packages)
-- Eksekusi file ini di Supabase SQL Editor: https://fgzmwmtssrviptflsjqy.supabase.co
-- ==============================================================================

-- Buat tabel resmi retail_starter_kits
CREATE TABLE IF NOT EXISTS public.retail_starter_kits (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  name TEXT NOT NULL,
  slug TEXT UNIQUE,
  badge TEXT,
  price INT NOT NULL DEFAULT 0,
  original_price INT,
  description TEXT,
  suitable_for TEXT,
  items_included JSONB NOT NULL DEFAULT '[]',
  is_popular BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Buat tabel retail_starter_kit_items
CREATE TABLE IF NOT EXISTS public.retail_starter_kit_items (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  starter_kit_id TEXT NOT NULL,
  master_catalog_id TEXT,
  product_name TEXT NOT NULL,
  barcode TEXT,
  quantity INT NOT NULL DEFAULT 1,
  unit TEXT DEFAULT 'Pcs',
  unit_base_price INT DEFAULT 0,
  unit_selling_price INT DEFAULT 0,
  category TEXT DEFAULT 'Sembako',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_rski_starter_kit_id ON public.retail_starter_kit_items(starter_kit_id);

-- Aktifkan RLS
ALTER TABLE public.retail_starter_kits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.retail_starter_kit_items ENABLE ROW LEVEL SECURITY;

-- Policy publik untuk membaca katalog paket retail
DROP POLICY IF EXISTS "Anyone can view active starter kits" ON public.retail_starter_kits;
CREATE POLICY "Anyone can view active starter kits"
  ON public.retail_starter_kits
  FOR SELECT
  USING (true);

-- Policy admin untuk mengelola (CRUD) paket usaha
DROP POLICY IF EXISTS "Admins can manage starter kits" ON public.retail_starter_kits;
CREATE POLICY "Admins can manage starter kits"
  ON public.retail_starter_kits
  FOR ALL
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "retail_starter_kit_items_read_all" ON public.retail_starter_kit_items;
CREATE POLICY "retail_starter_kit_items_read_all"
  ON public.retail_starter_kit_items
  FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "retail_starter_kit_items_manage_all" ON public.retail_starter_kit_items;
CREATE POLICY "retail_starter_kit_items_manage_all"
  ON public.retail_starter_kit_items
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Bersihkan objek lama hardware_packages secara aman (Cek tipe: TABLE vs VIEW)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname = 'public' AND viewname = 'hardware_packages') THEN
    EXECUTE 'DROP VIEW public.hardware_packages CASCADE';
  ELSIF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'hardware_packages') THEN
    EXECUTE 'DROP TABLE public.hardware_packages CASCADE';
  END IF;
END $$;

-- View kompatibilitas backward (agar kueri lama hardware_packages tetap jalan tanpa error)
CREATE OR REPLACE VIEW public.hardware_packages AS
SELECT * FROM public.retail_starter_kits;

-- Masukkan 4 Paket Usaha Resmi Syupeo (@ Rp 200.000)
INSERT INTO public.retail_starter_kits (
  slug,
  name,
  badge,
  price,
  original_price,
  description,
  suitable_for,
  items_included,
  is_popular,
  is_active,
  sort_order
)
VALUES
  (
    'paket-01-toko-pemula',
    'Paket 01 — Toko Pemula',
    'FAVORIT KELUARGA 🌾',
    200000,
    240000,
    'Stok sembako & kebutuhan harian rutin yang paling cepat berputar di lingkungan perumahan.',
    'Tetangga, Usaha Rumahan, Kos-kosan, Komunitas Lingkungan',
    '[
      "Beras Premium 2 kg (Bahan Pokok)",
      "Minyak Goreng 1 Liter & Gula Pasir 1 kg",
      "Tepung Terigu 1 kg & Mi Instan Pilihan (5 pcs)",
      "Kopi Sachet Nikmat (10 pcs) & Teh Pilihan",
      "Sabun Mandi (2 pcs) & Sabun Cuci Piring",
      "Deterjen Pakaian & Pasta Gigi Keluarga",
      "Kecap Manis, Tisu & Perlengkapan Kemasan Toko",
      "Aplikasi Kasir POS & Backoffice Syupeo 100% GRATIS",
      "Web Toko Online Siap Pakai & Dukungan QRIS Kasir"
    ]'::jsonb,
    TRUE,
    TRUE,
    1
  ),
  (
    'paket-02-gen-z-box',
    'Paket 02 — Gen Z Box',
    'TREN VIRAL 🔥',
    200000,
    260000,
    'Aksesori kekinian & fashion items margin tinggi yang sangat diminati kalangan anak muda.',
    'Mahasiswa, Pelajar, Reseller Kampus, TikTok & Instagram Shop',
    '[
      "Phone Charm Kekinian (5 pcs)",
      "Pop Socket Karakter Trendi (3 pcs)",
      "Pelindung Kabel Handphone (5 pcs)",
      "Scrunchie Rambut (5 pcs) & Jepit Rambut Korea (4 pcs)",
      "Gantungan Kunci Estetik (5 pcs) & Stiker Pack (10 pcs)",
      "Kaos Kaki Korea Stylish (3 pasang)",
      "Mini Tote Bag (2 pcs) & Mini Pouch Cantik (2 pcs)",
      "Alokasi Kemasan Estetik Siap Display",
      "Aplikasi Kasir POS & Backoffice Syupeo 100% GRATIS",
      "Katalog Online untuk Share Status WA & Medsos"
    ]'::jsonb,
    FALSE,
    TRUE,
    2
  ),
  (
    'paket-03-beauty-box',
    'Paket 03 — Beauty Box Makarizo',
    'STOK RESELLER 💄',
    200000,
    250000,
    'Stok produk perawatan & kecantikan resmi Makarizo untuk dijual kembali dengan margin menarik.',
    'Reseller Kecantikan, Mahasiswi, Salon Rumahan, Beauty Content Creator',
    '[
      "Produk Perawatan Rambut & Tubuh Makarizo Resmi",
      "Produk Kecantikan Pelengkap Terlaris",
      "Kemasan Reseller Eksklusif (Pouch & Label Toko)",
      "Cadangan Biaya Operasional & Kemasan Rapi",
      "Materi Promosi Foto Produk Asli & Konten Video Pendek",
      "Aplikasi Kasir POS & Backoffice Syupeo 100% GRATIS",
      "Toko Online Pribadi untuk Terima Order Langsung"
    ]'::jsonb,
    FALSE,
    TRUE,
    3
  ),
  (
    'paket-04-air-mineral',
    'Paket 04 — Air Mineral (VICA + Pure Life)',
    'KEBUTUHAN RUTIN 💧',
    200000,
    225000,
    'Paket air minum siap jual dari brand terpercaya dengan perputaran repeat order sangat tinggi.',
    'Warung, Rumah Tangga, Kantor Kecil, Kos-kosan, Tempat Usaha',
    '[
      "1 Karton VICA 600 mL Tutup Kuning (24 Botol) @ Rp 84.000",
      "1 Galon Nestlé Pure Life 19 Liter @ Rp 70.000",
      "Alokasi Kemasan & Cadangan Biaya Operasional @ Rp 46.000",
      "Acuan: VICA 600 mL Tutup Kuning Label Biru-Hijau Resmi",
      "Panduan Lengkap Kebijakan Galon & Mekanisme Penukaran",
      "Aplikasi Kasir POS & Backoffice Syupeo 100% GRATIS",
      "Pencatatan Pelanggan Rutin & Riwayat Order Otomatis"
    ]'::jsonb,
    FALSE,
    TRUE,
    4
  )
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  badge = EXCLUDED.badge,
  price = EXCLUDED.price,
  original_price = EXCLUDED.original_price,
  description = EXCLUDED.description,
  suitable_for = EXCLUDED.suitable_for,
  items_included = EXCLUDED.items_included,
  is_popular = EXCLUDED.is_popular,
  is_active = EXCLUDED.is_active,
  sort_order = EXCLUDED.sort_order,
  updated_at = timezone('utc'::text, now());
