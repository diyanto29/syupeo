-- ==============================================================================
-- SYUPEO COMPREHENSIVE FIX: STORAGE BUCKET & ADMIN USERS RLS RESOLUTION
-- Eksekusi file SQL ini di Supabase Dashboard -> SQL Editor:
-- https://fgzmwmtssrviptflsjqy.supabase.co
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. SETUP STORAGE BUCKET: menu-item-images (Public Bucket)
-- ------------------------------------------------------------------------------
DO $$
BEGIN
  -- Insert bucket jika belum ada
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
END $$;

-- Policy Storage: Public Read
DROP POLICY IF EXISTS "menu_item_images_public_read" ON storage.objects;
CREATE POLICY "menu_item_images_public_read"
ON storage.objects FOR SELECT
USING (bucket_id = 'menu-item-images');

-- Policy Storage: Upload (Insert)
DROP POLICY IF EXISTS "menu_item_images_upload_policy" ON storage.objects;
CREATE POLICY "menu_item_images_upload_policy"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'menu-item-images');

-- Policy Storage: Update & Delete
DROP POLICY IF EXISTS "menu_item_images_update_policy" ON storage.objects;
CREATE POLICY "menu_item_images_update_policy"
ON storage.objects FOR UPDATE
USING (bucket_id = 'menu-item-images')
WITH CHECK (bucket_id = 'menu-item-images');

DROP POLICY IF EXISTS "menu_item_images_delete_policy" ON storage.objects;
CREATE POLICY "menu_item_images_delete_policy"
ON storage.objects FOR DELETE
USING (bucket_id = 'menu-item-images');

-- ------------------------------------------------------------------------------
-- 2. SETUP KOLOM master_catalog & admin_users (PASTIKAN SEMUA KOLOM TERSEDIA)
-- ------------------------------------------------------------------------------
-- 2a. Kolom image_url pada master_catalog
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'master_catalog' AND column_name = 'image_url'
  ) THEN
    ALTER TABLE public.master_catalog ADD COLUMN image_url TEXT;
  END IF;
END $$;

-- 2b. Kolom user_id, partner_id, can_manage_licenses pada admin_users
ALTER TABLE public.admin_users
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS partner_id UUID,
  ADD COLUMN IF NOT EXISTS can_manage_licenses BOOLEAN DEFAULT false;

-- Longgarkan constraint role jika ada
ALTER TABLE public.admin_users DROP CONSTRAINT IF EXISTS admin_users_role_check;
ALTER TABLE public.admin_users ADD CONSTRAINT admin_users_role_check CHECK (role IN ('super_admin', 'admin', 'partner'));

-- ------------------------------------------------------------------------------
-- 3. PERBAIKAN ROBUST FUNGSI public.is_admin()
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_uid uuid;
  v_email text;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN FALSE;
  END IF;

  -- 1. Ekstraksi email dari JWT claim atau auth.users
  v_email := LOWER(COALESCE(
    auth.jwt() ->> 'email',
    (SELECT email FROM auth.users WHERE id = v_uid)
  ));

  -- 2. Master Super Admin Hardcoded
  IF v_email = 'diyanto2911@gmail.com' THEN
    RETURN TRUE;
  END IF;

  -- 3. Cek di tabel admin_users berdasarkan email atau user_id
  RETURN EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE (
      (v_email IS NOT NULL AND LOWER(email) = v_email)
      OR user_id = v_uid
    )
    AND is_active = true
    AND role IN ('super_admin', 'admin')
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, anon;

-- ------------------------------------------------------------------------------
-- 4. PERBAIKAN ROW LEVEL SECURITY (RLS) PADA TABEL admin_users
-- ------------------------------------------------------------------------------
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;

-- 4a. SELECT Policy (Gunakan public.is_admin(), jangan SELECT langsung ke auth.users)
DROP POLICY IF EXISTS "Allow admins to select admin_users" ON public.admin_users;
DROP POLICY IF EXISTS "Allow partners and admins to select admin_users" ON public.admin_users;
CREATE POLICY "Allow partners and admins to select admin_users" ON public.admin_users
FOR SELECT TO authenticated
USING (
  public.is_admin()
  OR user_id = auth.uid()
  OR LOWER(email) = LOWER(COALESCE(auth.jwt() ->> 'email', ''))
);

-- 4b. INSERT Policy
DROP POLICY IF EXISTS "Allow admins to insert admin_users" ON public.admin_users;
CREATE POLICY "Allow admins to insert admin_users" ON public.admin_users
FOR INSERT TO authenticated
WITH CHECK (
  public.is_admin()
);

-- 4c. UPDATE Policy
DROP POLICY IF EXISTS "Allow admins to update admin_users" ON public.admin_users;
CREATE POLICY "Allow admins to update admin_users" ON public.admin_users
FOR UPDATE TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- 4d. DELETE Policy
DROP POLICY IF EXISTS "Allow admins to delete admin_users" ON public.admin_users;
CREATE POLICY "Allow admins to delete admin_users" ON public.admin_users
FOR DELETE TO authenticated
USING (
  public.is_admin()
  AND LOWER(email) <> 'diyanto2911@gmail.com'
);

-- ------------------------------------------------------------------------------
-- 5. RPC FUNCTIONS: manage_admin_user & delete_admin_user (SECURITY DEFINER)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.manage_admin_user(
  p_id UUID DEFAULT NULL,
  p_email TEXT DEFAULT '',
  p_name TEXT DEFAULT NULL,
  p_role TEXT DEFAULT 'admin',
  p_partner_id UUID DEFAULT NULL,
  p_is_active BOOLEAN DEFAULT true,
  p_can_manage_licenses BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_clean_email TEXT;
  v_res RECORD;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Akses ditolak: Anda tidak memiliki wewenang Super Admin.';
  END IF;

  v_clean_email := LOWER(TRIM(p_email));
  IF v_clean_email = '' THEN
    RAISE EXCEPTION 'Email admin wajib diisi.';
  END IF;

  IF p_id IS NOT NULL THEN
    UPDATE public.admin_users
    SET
      name = NULLIF(TRIM(p_name), ''),
      role = p_role,
      partner_id = CASE WHEN p_role = 'partner' THEN p_partner_id ELSE NULL END,
      is_active = p_is_active,
      can_manage_licenses = CASE WHEN p_role = 'super_admin' THEN true ELSE p_can_manage_licenses END,
      updated_at = NOW()
    WHERE id = p_id
    RETURNING * INTO v_res;
  ELSE
    INSERT INTO public.admin_users (
      email,
      name,
      role,
      partner_id,
      is_active,
      can_manage_licenses,
      created_at,
      updated_at
    )
    VALUES (
      v_clean_email,
      NULLIF(TRIM(p_name), ''),
      p_role,
      CASE WHEN p_role = 'partner' THEN p_partner_id ELSE NULL END,
      p_is_active,
      CASE WHEN p_role = 'super_admin' THEN true ELSE p_can_manage_licenses END,
      NOW(),
      NOW()
    )
    ON CONFLICT (email) DO UPDATE
    SET
      name = COALESCE(EXCLUDED.name, public.admin_users.name),
      role = EXCLUDED.role,
      partner_id = EXCLUDED.partner_id,
      is_active = EXCLUDED.is_active,
      can_manage_licenses = EXCLUDED.can_manage_licenses,
      updated_at = NOW()
    RETURNING * INTO v_res;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Admin user berhasil disimpan.',
    'data', to_jsonb(v_res)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.manage_admin_user TO authenticated;

-- RPC Delete Admin
CREATE OR REPLACE FUNCTION public.delete_admin_user(p_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_target_email TEXT;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Akses ditolak: Anda tidak memiliki wewenang Super Admin.';
  END IF;

  SELECT email INTO v_target_email FROM public.admin_users WHERE id = p_id;

  IF v_target_email IS NULL THEN
    RAISE EXCEPTION 'Data admin tidak ditemukan.';
  END IF;

  IF LOWER(v_target_email) = 'diyanto2911@gmail.com' THEN
    RAISE EXCEPTION 'Akun Super Admin Utama (diyanto2911@gmail.com) tidak dapat dihapus.';
  END IF;

  DELETE FROM public.admin_users WHERE id = p_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Akun admin berhasil dihapus.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_admin_user TO authenticated;

-- ------------------------------------------------------------------------------
-- 6. PASTIKAN AKUN SUPER ADMIN UTAMA TERDAFTAR DI admin_users
-- ------------------------------------------------------------------------------
INSERT INTO public.admin_users (email, name, role, is_active, can_manage_licenses)
VALUES (
  'diyanto2911@gmail.com',
  'Diyanto (Super Admin)',
  'super_admin',
  true,
  true
)
ON CONFLICT (email) DO UPDATE
SET role = 'super_admin',
    is_active = true,
    can_manage_licenses = true;
