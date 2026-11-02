-- ==============================================================================
-- SETUP AKUN DEMO REVIEWER GOOGLE PLAY & SAKLAR ON/OFF DARI SUPABASE
-- Eksekusi di Supabase Dashboard -> SQL Editor: https://fgzmwmtssrviptflsjqy.supabase.co
-- ==============================================================================

-- 1. Buat Tabel app_configurations (Untuk Kontrol Saklar Tombol Demo dari Cloud)
CREATE TABLE IF NOT EXISTS public.app_configurations (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.app_configurations ENABLE ROW LEVEL SECURITY;

-- Siapa saja (anon & authenticated) bisa membaca konfigurasi publik
DROP POLICY IF EXISTS "Public can view app_configurations" ON public.app_configurations;
CREATE POLICY "Public can view app_configurations"
ON public.app_configurations FOR SELECT
USING (true);

-- Hanya Super Admin yang bisa mengedit
DROP POLICY IF EXISTS "Admins can manage app_configurations" ON public.app_configurations;
CREATE POLICY "Admins can manage app_configurations"
ON public.app_configurations FOR ALL
USING (public.is_admin());

-- Masukkan Saklar show_demo_login: DEFAULT TRUE (Aktif saat masa review)
INSERT INTO public.app_configurations (key, value, description)
VALUES ('show_demo_login', 'true'::jsonb, 'Saklar menampilkan tombol Masuk Akun Demo Reviewer di aplikasi POS')
ON CONFLICT (key) DO UPDATE
SET value = 'true'::jsonb, updated_at = timezone('utc'::text, now());


-- 2. Buat Akun Tester Reviewer (reviewer@syupeo.com) di auth.users & public.profiles
DO $$
DECLARE
  v_user_id UUID := 'a0000000-0000-0000-0000-000000000001';
  v_business_id UUID := 'b0000000-0000-0000-0000-000000000001';
  v_outlet_id UUID := 'c0000000-0000-0000-0000-000000000001';
  v_category_id UUID := 'd0000000-0000-0000-0000-000000000001';
BEGIN
  -- Insert ke auth.users jika belum ada
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'reviewer@syupeo.com') THEN
    INSERT INTO auth.users (
      id,
      instance_id,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      role,
      aud
    )
    VALUES (
      v_user_id,
      '00000000-0000-0000-0000-000000000000',
      'reviewer@syupeo.com',
      crypt('DemoReviewer2026!', gen_salt('bf')),
      NOW(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"name":"Google Play Reviewer","full_name":"Google Play Reviewer"}'::jsonb,
      NOW(),
      NOW(),
      'authenticated',
      'authenticated'
    );
  ELSE
    SELECT id INTO v_user_id FROM auth.users WHERE email = 'reviewer@syupeo.com';
    UPDATE auth.users
    SET encrypted_password = crypt('DemoReviewer2026!', gen_salt('bf')),
        email_confirmed_at = COALESCE(email_confirmed_at, NOW())
    WHERE id = v_user_id;
  END IF;

  -- Insert/Update ke public.profiles
  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    default_role,
    is_active,
    onboarding_completed,
    created_at,
    updated_at
  )
  VALUES (
    v_user_id,
    'reviewer@syupeo.com',
    'Google Play Reviewer',
    'owner',
    true,
    true,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET is_active = true, onboarding_completed = true;

  -- Buat Toko Demo untuk Reviewer (Retail POS)
  INSERT INTO public.businesses (
    id,
    name,
    slug,
    business_type,
    owner_user_id,
    status,
    phone,
    email,
    address,
    city,
    subscription_status,
    max_transactions,
    max_products,
    max_outlets,
    created_at,
    updated_at
  )
  VALUES (
    v_business_id,
    'Toko Demo Syupeo (Reviewer)',
    'toko-demo-reviewer',
    'retail',
    v_user_id,
    'active',
    '081234567890',
    'reviewer@syupeo.com',
    'Jl. Thamrin No. 10',
    'Jakarta Pusat',
    'active',
    10000,
    5000,
    5,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET owner_user_id = v_user_id, status = 'active';

  -- Buat Business Member (Owner)
  INSERT INTO public.business_members (
    business_id,
    user_id,
    role,
    status,
    created_at,
    updated_at
  )
  VALUES (
    v_business_id,
    v_user_id,
    'owner',
    'active',
    NOW(),
    NOW()
  )
  ON CONFLICT (business_id, user_id) DO UPDATE
  SET role = 'owner', status = 'active';

  -- Buat Outlet Utama Toko Demo
  INSERT INTO public.outlets (
    id,
    business_id,
    name,
    code,
    address,
    phone,
    is_active,
    created_at,
    updated_at
  )
  VALUES (
    v_outlet_id,
    v_business_id,
    'Kasir Toko Utama',
    'MAIN-01',
    'Jl. Thamrin No. 10, Jakarta Pusat',
    '081234567890',
    true,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET is_active = true;

  -- Hubungkan Reviewer ke Outlet
  INSERT INTO public.outlet_members (
    outlet_id,
    user_id,
    role,
    created_at
  )
  VALUES (
    v_outlet_id,
    v_user_id,
    'owner',
    NOW()
  )
  ON CONFLICT (outlet_id, user_id) DO NOTHING;

  -- Buat Kategori Produk Contoh
  INSERT INTO public.categories (
    id,
    business_id,
    name,
    is_active,
    created_at
  )
  VALUES (
    v_category_id,
    v_business_id,
    'Sembako & Minuman',
    true,
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;

  -- Buat Produk Demo Contoh di Kasir
  INSERT INTO public.menu_items (
    business_id,
    category_id,
    name,
    description,
    price,
    cost_price,
    track_stock,
    is_available,
    barcode,
    created_at
  )
  VALUES 
    (v_business_id, v_category_id, 'Minyak Goreng Kita 1L', 'Minyak goreng kemasan bantal', 14000, 12500, true, true, '899990800101', NOW()),
    (v_business_id, v_category_id, 'Beras Ramos Super 5kg', 'Beras putih pulen pilihan', 68000, 60000, true, true, '899990800102', NOW()),
    (v_business_id, v_category_id, 'Kopi Toobagus Robusta 100g', 'Kopi tubruk robusta murni', 15000, 10000, true, true, '899990800103', NOW())
  ON CONFLICT DO NOTHING;

END $$;
