-- ==============================================================================
-- SEED DEMO STAFF / KASIR UNTUK GOOGLE PLAY CONSOLE REVIEW & TESTING
-- ==============================================================================
-- Script ini membuat/me-reset akun staf demo dengan kredensial:
--   Staff ID : SF-2024-001
--   Password : Mangga123!
--
-- Akun ini langsung siap digunakan di login aplikasi mobile Mangga POS
-- dan dicantumkan ke Google Play Console > App Access (Akses Aplikasi).
-- ==============================================================================

DO $$
DECLARE
  v_business_id uuid;
BEGIN
  -- Cari bisnis aktif pertama di database
  SELECT id INTO v_business_id FROM public.businesses ORDER BY created_at ASC LIMIT 1;

  IF v_business_id IS NOT NULL THEN
    INSERT INTO public.staff_invitations (
      business_id,
      staff_code,
      full_name,
      email,
      role,
      status,
      initial_password_hash
    )
    VALUES (
      v_business_id,
      'SF-2024-001',
      'Staff Kasir Demo',
      'demo.reviewer@manggapos.com',
      'cashier',
      'invited',
      extensions.crypt('Mangga123!', extensions.gen_salt('bf'))
    )
    ON CONFLICT (business_id, staff_code) DO UPDATE
    SET
      full_name = EXCLUDED.full_name,
      status = 'invited',
      claimed_by_user_id = NULL,
      initial_password_hash = EXCLUDED.initial_password_hash;

    RAISE NOTICE 'Sukses: Staf demo SF-2024-001 (Password: Mangga123!) siap digunakan untuk bisnis %', v_business_id;
  ELSE
    RAISE EXCEPTION 'Belum ada bisnis di tabel public.businesses. Silakan login Owner terlebih dahulu di aplikasi untuk membuat bisnis.';
  END IF;
END $$;
