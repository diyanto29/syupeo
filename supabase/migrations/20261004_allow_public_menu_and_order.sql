-- ==============================================================================
-- IZINKAN PELANGGAN PUBLIK (ANON) MEMBACA MENU DIGITAL & SELF-ORDER QR
-- ==============================================================================
-- Script ini memperbaiki error column "is_active" does not exist dengan
-- menggunakan USING (true) agar seluruh pengunjung publik (anon) dapat
-- membuka link menu digital dan QR self-order.
-- ==============================================================================

-- 1. Tabel Businesses (Bisa dibaca publik untuk profil toko)
DROP POLICY IF EXISTS "businesses_select_public" ON public.businesses;
CREATE POLICY "businesses_select_public"
ON public.businesses
FOR SELECT
TO anon, authenticated
USING (
  true
);

-- 2. Tabel Outlets (Bisa dibaca publik untuk data cabang/outlet)
DROP POLICY IF EXISTS "outlets_select_public" ON public.outlets;
CREATE POLICY "outlets_select_public"
ON public.outlets
FOR SELECT
TO anon, authenticated
USING (
  true
);

-- 3. Tabel Menu Items (Bisa dibaca publik untuk daftar produk)
DROP POLICY IF EXISTS "menu_items_select_public" ON public.menu_items;
CREATE POLICY "menu_items_select_public"
ON public.menu_items
FOR SELECT
TO anon, authenticated
USING (
  true
);

-- 4. Tabel Kategori Menu (Bisa dibaca publik)
DROP POLICY IF EXISTS "menu_categories_select_public" ON public.menu_categories;
CREATE POLICY "menu_categories_select_public"
ON public.menu_categories
FOR SELECT
TO anon, authenticated
USING (
  true
);

-- 5. Tabel Varian Menu (Bisa dibaca publik)
DROP POLICY IF EXISTS "menu_item_variants_select_public" ON public.menu_item_variants;
CREATE POLICY "menu_item_variants_select_public"
ON public.menu_item_variants
FOR SELECT
TO anon, authenticated
USING (
  true
);
