-- ==============================================================================
-- FIX GO-TRUE AUTH 500 ERROR ("Database error querying schema")
-- Eksekusi di Supabase Dashboard -> SQL Editor: https://fgzmwmtssrviptflsjqy.supabase.co
-- ==============================================================================

-- 1. Tambahkan kolom default_role & role di public.profiles agar trigger auth tidak pernah error
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'default_role'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN default_role text DEFAULT 'owner';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN role text DEFAULT 'owner';
  END IF;
END $$;

-- 2. Perbaiki fungsi trigger auth user upsert agar tidak pernah gagal
CREATE OR REPLACE FUNCTION public.handle_auth_user_upsert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  provider_name text;
BEGIN
  provider_name := coalesce(new.raw_app_meta_data ->> 'provider', 'google');

  INSERT INTO public.profiles (
    id,
    email,
    phone,
    full_name,
    avatar_url,
    auth_provider,
    last_sign_in_at,
    created_at,
    updated_at
  )
  VALUES (
    new.id,
    new.email,
    new.phone,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(new.email, '@', 1)
    ),
    new.raw_user_meta_data ->> 'avatar_url',
    provider_name,
    timezone('utc', now()),
    timezone('utc', now()),
    timezone('utc', now())
  )
  ON CONFLICT (id) DO UPDATE
  SET
    email = coalesce(excluded.email, public.profiles.email),
    phone = coalesce(excluded.phone, public.profiles.phone),
    full_name = coalesce(excluded.full_name, public.profiles.full_name),
    avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url),
    auth_provider = coalesce(excluded.auth_provider, public.profiles.auth_provider),
    last_sign_in_at = timezone('utc', now()),
    updated_at = timezone('utc', now());

  BEGIN
    UPDATE public.profiles SET role = 'owner', default_role = 'owner' WHERE id = new.id;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  RETURN new;
END;
$$;

-- 3. Perbaiki semua kolom NULL di auth.users (Penyebab utama GoTrue 500: converting NULL to string is unsupported)
UPDATE auth.users
SET 
  confirmation_token = COALESCE(confirmation_token, ''),
  email_change = COALESCE(email_change, ''),
  email_change_token_new = COALESCE(email_change_token_new, ''),
  recovery_token = COALESCE(recovery_token, ''),
  email_change_token_current = COALESCE(email_change_token_current, ''),
  phone_change = COALESCE(phone_change, ''),
  phone_change_token = COALESCE(phone_change_token, ''),
  reauthentication_token = COALESCE(reauthentication_token, '')
WHERE 
  confirmation_token IS NULL 
  OR email_change IS NULL 
  OR email_change_token_new IS NULL 
  OR recovery_token IS NULL;

-- 4. Pastikan reviewer@syupeo.com memiliki semua token string kosong, password valid, dan status confirmed
UPDATE auth.users
SET 
  encrypted_password = crypt('DemoReviewer2026!', gen_salt('bf')),
  email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
  confirmation_token = '',
  recovery_token = '',
  email_change = '',
  email_change_token_new = '',
  email_change_token_current = '',
  phone_change = '',
  phone_change_token = '',
  reauthentication_token = '',
  raw_app_meta_data = '{"provider":"email","providers":["email"]}'::jsonb,
  raw_user_meta_data = '{"name":"Google Play Reviewer","full_name":"Google Play Reviewer"}'::jsonb,
  aud = 'authenticated',
  role = 'authenticated',
  updated_at = NOW()
WHERE email = 'reviewer@syupeo.com';

-- 5. Daftarkan identitas provider 'email' ke auth.identities
DO $$
DECLARE
  v_user_id UUID;
  v_has_provider_id BOOLEAN;
BEGIN
  SELECT id INTO v_user_id FROM auth.users WHERE email = 'reviewer@syupeo.com';

  IF v_user_id IS NOT NULL THEN
    -- Hapus identity lama jika ada untuk user ini agar bersih
    DELETE FROM auth.identities WHERE user_id = v_user_id;

    -- Cek apakah tabel auth.identities memiliki kolom provider_id (versi Supabase baru)
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'auth' AND table_name = 'identities' AND column_name = 'provider_id'
    ) INTO v_has_provider_id;

    IF v_has_provider_id THEN
      EXECUTE '
        INSERT INTO auth.identities (
          id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
        )
        VALUES (
          $1, $2, $3, 
          jsonb_build_object(''sub'', $3::text, ''email'', ''reviewer@syupeo.com'', ''email_verified'', true),
          ''email'', NOW(), NOW(), NOW()
        )'
      USING v_user_id::text, 'reviewer@syupeo.com', v_user_id;
    ELSE
      EXECUTE '
        INSERT INTO auth.identities (
          id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
        )
        VALUES (
          $1, $2, 
          jsonb_build_object(''sub'', $2::text, ''email'', ''reviewer@syupeo.com'', ''email_verified'', true),
          ''email'', NOW(), NOW(), NOW()
        )'
      USING v_user_id::text, v_user_id;
    END IF;
  END IF;
END $$;

