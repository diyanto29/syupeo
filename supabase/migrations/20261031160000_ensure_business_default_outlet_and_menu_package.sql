-- ==============================================================================
-- SYUPEO DATABASE MIGRATION SYSTEM
-- Migration: 20261031160000_ensure_business_default_outlet_and_menu_package.sql
-- Description:
-- 1. Tambahkan kolom yang belum ada (ALTER TABLE ADD COLUMN IF NOT EXISTS)
-- 2. Helper function is_business_owner & is_business_member
-- 3. Buat tabel menu_package_items dengan foreign key eksplisit
-- 4. Kebijakan RLS lengkap (INSERT, UPDATE, DELETE) pada tabel outlets & outlet_members
-- 5. Fungsi RPC ensure_business_default_outlet(p_business_id) untuk auto-heal outlet toko
-- 6. Perbarui activate_business agar otomatis memanggil ensure_business_default_outlet
-- 7. Auto-heal seluruh toko yang belum memiliki outlet
-- ==============================================================================

-- 1. Sinkronisasi kolom fisik tabel outlets, outlet_members, dan menu_items jika belum ada
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS timezone TEXT NOT NULL DEFAULT 'Asia/Jakarta';
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS geofence_radius INT DEFAULT 5000;
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS is_geofence_active BOOLEAN DEFAULT true;
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS tax_enabled BOOLEAN DEFAULT false;
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS tax_name TEXT DEFAULT 'PB1';
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS tax_rate NUMERIC(5,2) DEFAULT 10.0;
ALTER TABLE public.outlets ADD COLUMN IF NOT EXISTS is_tax_inclusive BOOLEAN DEFAULT false;

ALTER TABLE public.outlet_members ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';

ALTER TABLE public.menu_items ADD COLUMN IF NOT EXISTS is_package BOOLEAN NOT NULL DEFAULT false;

-- 2. Helper function is_business_owner & is_business_member
CREATE OR REPLACE FUNCTION public.is_business_owner(target_business_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.businesses b
    WHERE b.id = target_business_id
      AND b.owner_user_id = auth.uid()
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.is_business_owner(uuid) TO authenticated, anon, service_role;

CREATE OR REPLACE FUNCTION public.is_business_member(target_business_id uuid, target_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.business_members bm
    WHERE bm.business_id = target_business_id
      AND bm.user_id = target_user_id
      AND bm.status = 'active'
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.is_business_member(uuid, uuid) TO authenticated, anon, service_role;

-- 3. Buat tabel menu_package_items jika belum ada
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
CREATE POLICY "menu_package_items_select_all" ON public.menu_package_items
FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "menu_package_items_manage_all" ON public.menu_package_items;
CREATE POLICY "menu_package_items_manage_all" ON public.menu_package_items
FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 4. Kebijakan RLS Outlets & Outlet Members
DROP POLICY IF EXISTS "outlets_insert_owner" ON public.outlets;
CREATE POLICY "outlets_insert_owner" ON public.outlets
FOR INSERT TO authenticated
WITH CHECK (
  public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.businesses b
    WHERE b.id = outlets.business_id
      AND b.owner_user_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM public.business_members bm
    WHERE bm.business_id = outlets.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
  )
);

DROP POLICY IF EXISTS "outlets_update_owner" ON public.outlets;
CREATE POLICY "outlets_update_owner" ON public.outlets
FOR UPDATE TO authenticated
USING (
  public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.businesses b
    WHERE b.id = outlets.business_id
      AND b.owner_user_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM public.business_members bm
    WHERE bm.business_id = outlets.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
  )
)
WITH CHECK (
  public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.businesses b
    WHERE b.id = outlets.business_id
      AND b.owner_user_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM public.business_members bm
    WHERE bm.business_id = outlets.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
  )
);

DROP POLICY IF EXISTS "outlets_delete_owner" ON public.outlets;
CREATE POLICY "outlets_delete_owner" ON public.outlets
FOR DELETE TO authenticated
USING (
  public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.businesses b
    WHERE b.id = outlets.business_id
      AND b.owner_user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "outlet_members_insert_owner" ON public.outlet_members;
CREATE POLICY "outlet_members_insert_owner" ON public.outlet_members
FOR INSERT TO authenticated
WITH CHECK (
  public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.outlets o
    JOIN public.businesses b ON b.id = o.business_id
    WHERE o.id = outlet_members.outlet_id
      AND (b.owner_user_id = auth.uid() OR public.is_business_member(b.id, auth.uid()))
  )
);

DROP POLICY IF EXISTS "outlet_members_update_owner" ON public.outlet_members;
CREATE POLICY "outlet_members_update_owner" ON public.outlet_members
FOR UPDATE TO authenticated
USING (
  public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.outlets o
    JOIN public.businesses b ON b.id = o.business_id
    WHERE o.id = outlet_members.outlet_id
      AND (b.owner_user_id = auth.uid() OR public.is_business_member(b.id, auth.uid()))
  )
);

-- 5. Stored Procedure Auto-heal Outlet Toko Utama
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

  -- 1. Cek apakah outlet sudah ada
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

  -- 2. Pastikan owner terdaftar di outlet_members
  IF v_biz.owner_user_id IS NOT NULL AND v_outlet_id IS NOT NULL THEN
    INSERT INTO public.outlet_members (outlet_id, user_id, role, status)
    VALUES (v_outlet_id, v_biz.owner_user_id, 'owner', 'active')
    ON CONFLICT (outlet_id, user_id) DO UPDATE
    SET role = 'owner', status = 'active';
  END IF;

  RETURN jsonb_build_object('success', true, 'outlet_id', v_outlet_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.ensure_business_default_outlet(uuid) TO authenticated, anon, service_role;

-- 6. Update activate_business agar otomatis membuat outlet default
CREATE OR REPLACE FUNCTION public.activate_business(p_business_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_biz record;
BEGIN
  UPDATE public.businesses
  SET status = 'active',
      subscription_status = 'active',
      updated_at = timezone('utc'::text, now())
  WHERE id = p_business_id
  RETURNING * INTO v_biz;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bisnis dengan ID % tidak ditemukan.', p_business_id;
  END IF;

  -- Pastikan outlet default toko sudah tercipta
  PERFORM public.ensure_business_default_outlet(p_business_id);

  -- Update pesanan paket usaha ke packing
  IF v_biz.phone IS NOT NULL THEN
    UPDATE public.package_fulfillment_orders
    SET status = 'packing'
    WHERE recipient_phone = v_biz.phone
      AND status = 'pending_dispatch';
  END IF;

  -- Auto-seed produk starter kit
  IF v_biz.starter_kit_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.menu_items WHERE business_id = p_business_id LIMIT 1) THEN
      BEGIN
        PERFORM public.apply_starter_kit_to_business(p_business_id, v_biz.starter_kit_id);
      EXCEPTION WHEN OTHERS THEN
      END;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'business_id', p_business_id,
    'status', v_biz.status
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.activate_business(uuid) TO authenticated, anon, service_role;

-- 7. Auto-heal: Inisialisasi outlet utama untuk seluruh toko yang saat ini belum memiliki outlet
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN SELECT id FROM public.businesses LOOP
    PERFORM public.ensure_business_default_outlet(r.id);
  END LOOP;
END $$;
