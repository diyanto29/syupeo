-- Migration: Hardware Bundling & Cashier Packages System
-- Date: 2026-10-11
-- Purpose: Dynamic management of cashier hardware packages (printers, tablets, cash drawers, scanners) & PDF brochures

CREATE TABLE IF NOT EXISTS public.hardware_packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    slug VARCHAR(100) UNIQUE,
    badge VARCHAR(50) DEFAULT 'POPULER',
    price NUMERIC NOT NULL DEFAULT 0,
    original_price NUMERIC DEFAULT 0,
    description TEXT,
    suitable_for TEXT,
    items_included JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_popular BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexing
CREATE INDEX IF NOT EXISTS idx_hardware_packages_active ON public.hardware_packages(is_active);
CREATE INDEX IF NOT EXISTS idx_hardware_packages_sort ON public.hardware_packages(sort_order);

-- Enable RLS
ALTER TABLE public.hardware_packages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all to view active hardware packages" ON public.hardware_packages;
CREATE POLICY "Allow all to view active hardware packages"
ON public.hardware_packages FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Allow authenticated to manage hardware packages" ON public.hardware_packages;
CREATE POLICY "Allow authenticated to manage hardware packages"
ON public.hardware_packages FOR ALL
USING (auth.uid() IS NOT NULL)
WITH CHECK (auth.uid() IS NOT NULL);

-- Seed Initial Default Packages
INSERT INTO public.hardware_packages (name, slug, badge, price, original_price, description, suitable_for, items_included, is_popular, is_active, sort_order)
VALUES 
(
    'Paket Starter Mobile',
    'paket-starter-mobile',
    'HEMAT',
    499000,
    650000,
    'Solusi kasir praktis dan fleksibel untuk usaha bergerak atau ruang terbatas.',
    'Warung, Booth, Kedai Kaki Lima, Food Truck, Pedagang Keliling',
    '[
        "Printer Thermal Bluetooth 58mm Portable (Baterai Rechargeable)",
        "Gratis 5 Roll Kertas Struk Thermal",
        "Aplikasi Mangga POS PRO Lisensi 6 Bulan Penuh",
        "Toko Online & Menu Digital Otomatis (pos.mudahkan.online)",
        "Dukungan Cetak Struk & Pembayaran QRIS Dinamis",
        "Garansi Hardware Tukar Baru 1 Bulan & Pendampingan WA"
    ]'::jsonb,
    false,
    true,
    1
),
(
    'Paket Meja Kafe & Resto',
    'paket-meja-kafe-resto',
    'BEST SELLER 👑',
    2499000,
    3200000,
    'Set lengkap meja kasir modern siap pakai untuk F&B dan jasa profesional.',
    'Coffee Shop, Restoran, Kedai Kopi, Barbershop, Salon, Laundry',
    '[
        "Tablet Layar Jernih Android + Stand Holder Meja Kokoh",
        "Printer Kasir Thermal 58mm Auto Bluetooth & USB",
        "Laci Uang Kasir Logam Otomatis (Cash Drawer RJ11)",
        "Gratis 10 Roll Kertas Struk Kasir Berkualitas",
        "Lisensi Mangga POS PRO 1 Tahun Penuh (Tanpa Batas)",
        "Gratis Bantuan Input 30 Menu Awal & Logo Toko (Terima Beres)",
        "Fitur Manajemen Meja, Kitchen Display (KDS) & Split Bill",
        "Garansi Hardware 1 Tahun Resmi & Layanan Support Prioritas"
    ]'::jsonb,
    true,
    true,
    2
),
(
    'Paket Super Ritel & Minimarket',
    'paket-super-ritel-minimarket',
    'LENGKAP',
    3499000,
    4500000,
    'Perangkat kasir performa tinggi dengan barcode scanner cepat untuk toko kelontong dan ritel.',
    'Minimarket, Toko Sembako, Apotek, Toko Sparepart, Toko Bangunan',
    '[
        "Tablet Kasir Android 10 Inch / Layar Lebar Definisi Tinggi",
        "Barcode Scanner Laser Wireless 1D & 2D (Bisa Scan Layar HP & Dus Produk)",
        "Printer Thermal Struk Kasir Kecepatan Tinggi",
        "Laci Uang Kasir Logam Heavy-Duty (Cash Drawer RJ11)",
        "Master Katalog 10.000+ Barcode Produk Siap Pakai Langsung",
        "Lisensi Mangga POS PRO 1 Tahun Penuh (Tanpa Batas Transaksi)",
        "Fitur Stok Multi-Satuan (Pcs/Dus), Harga Grosir & Arus Kas Shift",
        "Garansi Hardware 1 Tahun & Training Penggunaan Lengkap"
    ]'::jsonb,
    false,
    true,
    3
)
ON CONFLICT (slug) DO NOTHING;
