-- Migration: Allow Admins to Clean Up and Delete Duplicate / Inactive Businesses
-- Date: 2026-10-10

-- 1. Function to cleanly delete a business and all its cascaded children safely
CREATE OR REPLACE FUNCTION public.delete_business_by_admin(p_business_id uuid)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Pastikan pemanggil adalah admin aktif atau super admin
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Akses ditolak: Hanya admin yang memiliki izin untuk menghapus bisnis.';
  END IF;

  -- 1. Hapus transaksi & relasinya jika ada
  DELETE FROM public.transaction_items WHERE transaction_id IN (SELECT id FROM public.transactions WHERE business_id = p_business_id);
  DELETE FROM public.transactions WHERE business_id = p_business_id;

  -- 2. Hapus menu, varian, tiered prices, kategori
  DELETE FROM public.menu_item_variants WHERE menu_item_id IN (SELECT id FROM public.menu_items WHERE business_id = p_business_id);
  DELETE FROM public.menu_item_tiered_prices WHERE menu_item_id IN (SELECT id FROM public.menu_items WHERE business_id = p_business_id);
  DELETE FROM public.menu_items WHERE business_id = p_business_id;
  DELETE FROM public.menu_categories WHERE business_id = p_business_id;

  -- 3. Hapus outlets dan anggotanya
  DELETE FROM public.outlet_members WHERE outlet_id IN (SELECT id FROM public.outlets WHERE business_id = p_business_id);
  DELETE FROM public.outlets WHERE business_id = p_business_id;

  -- 4. Hapus membership
  DELETE FROM public.business_members WHERE business_id = p_business_id;

  -- 5. Hapus riwayat langganan & penawaran jika tabelnya ada
  BEGIN
    DELETE FROM public.crm_quotations WHERE business_id = p_business_id;
  EXCEPTION WHEN undefined_table THEN
    -- abaikan jika tabel belum ada
  END;

  BEGIN
    DELETE FROM public.subscription_histories WHERE business_id = p_business_id;
  EXCEPTION WHEN undefined_table THEN
    -- abaikan jika tabel belum ada
  END;

  -- 6. Hapus data bisnis utama
  DELETE FROM public.businesses WHERE id = p_business_id;

  RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_business_by_admin(uuid) TO authenticated;

-- 2. Policy: Allow active admins to DELETE from businesses table directly
DROP POLICY IF EXISTS "Allow admins to delete businesses" ON public.businesses;
CREATE POLICY "Allow admins to delete businesses" ON public.businesses
FOR DELETE TO authenticated
USING (
  public.is_admin()
);

-- 3. Policy: Allow active admins to DELETE from outlets and members directly
DROP POLICY IF EXISTS "Allow admins to delete outlets" ON public.outlets;
CREATE POLICY "Allow admins to delete outlets" ON public.outlets
FOR DELETE TO authenticated
USING (
  public.is_admin()
);

DROP POLICY IF EXISTS "Allow admins to delete business_members" ON public.business_members;
CREATE POLICY "Allow admins to delete business_members" ON public.business_members
FOR DELETE TO authenticated
USING (
  public.is_admin()
);

DROP POLICY IF EXISTS "Allow admins to delete outlet_members" ON public.outlet_members;
CREATE POLICY "Allow admins to delete outlet_members" ON public.outlet_members
FOR DELETE TO authenticated
USING (
  public.is_admin()
);

-- ====================================================================
-- PEMBERSIHAN OTOMATIS: 4 TOKO DUPLIKAT YANG DITINGGALKAN
-- (Mempertahankan 4 toko terakhir pilihan user: terasama, IWDstore, SM_Konsultan, Toko Myra Greene Unique)
-- ====================================================================

-- 1. Hapus terasamma (pertahankan terasama)
DELETE FROM public.outlet_members WHERE outlet_id IN (SELECT id FROM public.outlets WHERE business_id = 'df6b8a22-53b7-4e44-8c0c-7ac6fbc72fe8');
DELETE FROM public.outlets WHERE business_id = 'df6b8a22-53b7-4e44-8c0c-7ac6fbc72fe8';
DELETE FROM public.business_members WHERE business_id = 'df6b8a22-53b7-4e44-8c0c-7ac6fbc72fe8';
DELETE FROM public.businesses WHERE id = 'df6b8a22-53b7-4e44-8c0c-7ac6fbc72fe8';

-- 2. Hapus IWD STORE (pertahankan IWDstore)
DELETE FROM public.outlet_members WHERE outlet_id IN (SELECT id FROM public.outlets WHERE business_id = 'a3bc3866-6f9f-4a91-8315-055519c3c3ce');
DELETE FROM public.outlets WHERE business_id = 'a3bc3866-6f9f-4a91-8315-055519c3c3ce';
DELETE FROM public.business_members WHERE business_id = 'a3bc3866-6f9f-4a91-8315-055519c3c3ce';
DELETE FROM public.businesses WHERE id = 'a3bc3866-6f9f-4a91-8315-055519c3c3ce';

-- 3. Hapus SM Konsultan (pertahankan SM_Konsultan)
DELETE FROM public.outlet_members WHERE outlet_id IN (SELECT id FROM public.outlets WHERE business_id = 'ede6876e-ad0a-4e2b-afab-28909bc1d7a5');
DELETE FROM public.outlets WHERE business_id = 'ede6876e-ad0a-4e2b-afab-28909bc1d7a5';
DELETE FROM public.business_members WHERE business_id = 'ede6876e-ad0a-4e2b-afab-28909bc1d7a5';
DELETE FROM public.businesses WHERE id = 'ede6876e-ad0a-4e2b-afab-28909bc1d7a5';

-- 4. Hapus Toko Myra Greene (pertahankan Toko Myra Greene Unique)
DELETE FROM public.outlet_members WHERE outlet_id IN (SELECT id FROM public.outlets WHERE business_id = 'add45757-09e0-49f0-8ca2-bbfe88f3724d');
DELETE FROM public.outlets WHERE business_id = 'add45757-09e0-49f0-8ca2-bbfe88f3724d';
DELETE FROM public.business_members WHERE business_id = 'add45757-09e0-49f0-8ca2-bbfe88f3724d';
DELETE FROM public.businesses WHERE id = 'add45757-09e0-49f0-8ca2-bbfe88f3724d';
