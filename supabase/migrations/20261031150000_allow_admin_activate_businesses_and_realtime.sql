-- ==============================================================================
-- SYUPEO DATABASE MIGRATION SYSTEM
-- Migration: 20261031150000_allow_admin_activate_businesses_and_realtime.sql
-- Description:
-- 1. Tambahkan sportdroid6@gmail.com & diyanto2911@gmail.com sebagai super admin
-- 2. Fungsi RPC SECURITY DEFINER activate_business(p_business_id) untuk aktivasi instan
-- 3. Daftarkan tabel businesses ke publikasi supabase_realtime
-- ==============================================================================

-- 1. Perbarui is_admin() agar mengenali kedua email super admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
DECLARE
  v_email text := LOWER(auth.jwt() ->> 'email');
BEGIN
  IF v_email IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Master super admin emails check
  IF v_email IN ('diyanto2911@gmail.com', 'sportdroid6@gmail.com') THEN
    RETURN TRUE;
  END IF;

  -- Cek tabel admin_users
  RETURN EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE LOWER(email) = v_email
      AND is_active = true
      AND role IN ('super_admin', 'admin')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, anon;

-- Pastikan kedua akun ada di tabel admin_users
INSERT INTO public.admin_users (email, role, is_active, can_manage_licenses)
VALUES 
  ('diyanto2911@gmail.com', 'super_admin', true, true),
  ('sportdroid6@gmail.com', 'super_admin', true, true)
ON CONFLICT (email) DO UPDATE 
SET role = 'super_admin', is_active = true, can_manage_licenses = true;

-- 2. Kebijakan RLS Update Businesses
DROP POLICY IF EXISTS "Allow admins to update all businesses" ON public.businesses;
CREATE POLICY "Allow admins to update all businesses" ON public.businesses
FOR UPDATE TO authenticated
USING (
  public.is_admin() 
  OR LOWER(auth.jwt() ->> 'email') IN ('diyanto2911@gmail.com', 'sportdroid6@gmail.com')
  OR owner_user_id = auth.uid()
)
WITH CHECK (
  public.is_admin() 
  OR LOWER(auth.jwt() ->> 'email') IN ('diyanto2911@gmail.com', 'sportdroid6@gmail.com')
  OR owner_user_id = auth.uid()
);

-- 3. Fungsi RPC SECURITY DEFINER untuk aktivasi toko secara bersih & atomik
CREATE OR REPLACE FUNCTION public.activate_business(p_business_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_biz record;
BEGIN
  -- Update status bisnis ke active
  UPDATE public.businesses
  SET status = 'active',
      subscription_status = 'active',
      updated_at = timezone('utc'::text, now())
  WHERE id = p_business_id
  RETURNING * INTO v_biz;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bisnis dengan ID % tidak ditemukan.', p_business_id;
  END IF;

  -- Update pesanan paket usaha ke packing jika ada
  IF v_biz.phone IS NOT NULL THEN
    UPDATE public.package_fulfillment_orders
    SET status = 'packing'
    WHERE recipient_phone = v_biz.phone
      AND status = 'pending_dispatch';
  END IF;

  -- 4. Auto-seed: Pastikan produk starter kit sudah tersalin ke menu_items toko
  IF v_biz.starter_kit_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.menu_items WHERE business_id = p_business_id LIMIT 1) THEN
      BEGIN
        PERFORM public.apply_starter_kit_to_business(p_business_id, v_biz.starter_kit_id);
      EXCEPTION WHEN OTHERS THEN
        -- Abaikan jika sudah ada atau terjadi duplicate
      END;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'id', v_biz.id,
    'name', v_biz.name,
    'status', v_biz.status
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.activate_business(uuid) TO authenticated, anon;

-- 4. Aktifkan Realtime Publikasi untuk businesses & package_fulfillment_orders
ALTER TABLE public.businesses REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'businesses'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.businesses;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'package_fulfillment_orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.package_fulfillment_orders;
  END IF;
END $$;

