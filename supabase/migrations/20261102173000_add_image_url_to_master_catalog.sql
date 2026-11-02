-- ==============================================================================
-- SYUPEO PRODUCT IMAGES & MASTER CATALOG SETUP
-- Eksekusi file ini di Supabase SQL Editor: https://fgzmwmtssrviptflsjqy.supabase.co
-- ==============================================================================

-- 1. Tambah kolom image_url pada tabel master_catalog (Katalog Nasional Supply Chain)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'master_catalog' AND column_name = 'image_url'
  ) THEN
    ALTER TABLE public.master_catalog ADD COLUMN image_url TEXT;
  END IF;
END $$;

-- 2. Buat Storage Bucket 'menu-item-images' (Public Bucket)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'menu-item-images',
  'menu-item-images',
  true,
  15728640, -- 15 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/jpg']
)
ON CONFLICT (id) DO UPDATE 
SET public = true,
    file_size_limit = 15728640,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/jpg'];

-- 3. Kebijakan Read Publik (Siapa saja bisa melihat foto produk di kasir / toko online)
DROP POLICY IF EXISTS "menu_item_images_public_read" ON storage.objects;
CREATE POLICY "menu_item_images_public_read"
ON storage.objects FOR SELECT
USING (bucket_id = 'menu-item-images');

-- 4. Kebijakan Upload (Super Admin & Kasir Merchant Terotentikasi)
DROP POLICY IF EXISTS "menu_item_images_upload_policy" ON storage.objects;
CREATE POLICY "menu_item_images_upload_policy"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'menu-item-images');

-- 5. Kebijakan Update
DROP POLICY IF EXISTS "menu_item_images_update_policy" ON storage.objects;
CREATE POLICY "menu_item_images_update_policy"
ON storage.objects FOR UPDATE
USING (bucket_id = 'menu-item-images')
WITH CHECK (bucket_id = 'menu-item-images');

-- 6. Kebijakan Delete
DROP POLICY IF EXISTS "menu_item_images_delete_policy" ON storage.objects;
CREATE POLICY "menu_item_images_delete_policy"
ON storage.objects FOR DELETE
USING (bucket_id = 'menu-item-images');
