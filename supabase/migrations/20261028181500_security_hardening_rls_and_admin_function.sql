-- Migration: Security Hardening - RLS Policies & Admin Function
-- Tanggal: 28 Oktober 2026
-- Mengatasi:
-- 1. SEC-05: Privilege escalation pada fungsi is_admin() yang menganggap role 'partner' sebagai admin penuh
-- 2. SEC-04: Kebijakan RLS permisif USING (true) pada tabel sensitif (app_licenses, partners, partner_commissions, partner_payouts, subscription_histories)

-- ============================================================================
-- 1. PERBAIKAN FUNGSI public.is_admin()
-- ============================================================================
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
DECLARE
  v_email text := LOWER(auth.jwt() ->> 'email');
BEGIN
  IF v_email IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Master super admin email check
  IF v_email = 'diyanto2911@gmail.com' THEN
    RETURN TRUE;
  END IF;

  -- Cek tabel admin_users HANYA untuk role super_admin dan admin (BUKAN partner)
  RETURN EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE LOWER(email) = v_email
      AND is_active = true
      AND role IN ('super_admin', 'admin')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, anon;

-- ============================================================================
-- 2. HELPER FUNCTIONS UNTUK PARTNER (Self-Contained)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_auth_email()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN LOWER(COALESCE(
    auth.jwt() ->> 'email',
    (SELECT email FROM auth.users WHERE id = v_uid)
  ));
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_auth_email() TO authenticated, anon;

CREATE OR REPLACE FUNCTION public.get_current_partner_id()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id UUID;
  v_email text;
  v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  v_email := public.get_auth_email();

  SELECT partner_id INTO v_partner_id
  FROM public.admin_users
  WHERE (
      (v_email IS NOT NULL AND LOWER(email) = v_email)
      OR (user_id IS NOT NULL AND user_id = v_uid)
    )
    AND is_active = true
    AND role = 'partner'
  LIMIT 1;

  RETURN v_partner_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_current_partner_id() TO authenticated, anon;

-- ============================================================================
-- 3. HARDENING RLS TABEL public.app_licenses
-- ============================================================================
ALTER TABLE public.app_licenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view app licenses" ON public.app_licenses;
DROP POLICY IF EXISTS "Admins can insert app licenses" ON public.app_licenses;
DROP POLICY IF EXISTS "Admins can update app licenses" ON public.app_licenses;
DROP POLICY IF EXISTS "Admins can delete app licenses" ON public.app_licenses;

CREATE POLICY "Admins can view app licenses"
    ON public.app_licenses
    FOR SELECT
    TO authenticated
    USING (public.is_admin());

CREATE POLICY "Admins can insert app licenses"
    ON public.app_licenses
    FOR INSERT
    TO authenticated
    WITH CHECK (public.is_admin());

CREATE POLICY "Admins can update app licenses"
    ON public.app_licenses
    FOR UPDATE
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

CREATE POLICY "Admins can delete app licenses"
    ON public.app_licenses
    FOR DELETE
    TO authenticated
    USING (public.is_admin());

-- ============================================================================
-- 4. HARDENING RLS TABEL public.partners
-- ============================================================================
-- Catatan: Tabel public.partners tidak memiliki kolom user_id. 
-- Akun user terhubung melalui public.admin_users.partner_id atau pencocokan email.
ALTER TABLE public.partners ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view partners" ON public.partners;
DROP POLICY IF EXISTS "Admins can insert partners" ON public.partners;
DROP POLICY IF EXISTS "Admins can update partners" ON public.partners;
DROP POLICY IF EXISTS "Admins can delete partners" ON public.partners;

CREATE POLICY "Admins can view partners"
    ON public.partners
    FOR SELECT
    TO authenticated
    USING (
      public.is_admin()
      OR id = public.get_current_partner_id()
      OR (email IS NOT NULL AND LOWER(email) = public.get_auth_email())
    );

CREATE POLICY "Admins can insert partners"
    ON public.partners
    FOR INSERT
    TO authenticated
    WITH CHECK (public.is_admin());

CREATE POLICY "Admins can update partners"
    ON public.partners
    FOR UPDATE
    TO authenticated
    USING (
      public.is_admin()
      OR id = public.get_current_partner_id()
      OR (email IS NOT NULL AND LOWER(email) = public.get_auth_email())
    )
    WITH CHECK (
      public.is_admin()
      OR id = public.get_current_partner_id()
      OR (email IS NOT NULL AND LOWER(email) = public.get_auth_email())
    );

CREATE POLICY "Admins can delete partners"
    ON public.partners
    FOR DELETE
    TO authenticated
    USING (public.is_admin());

-- ============================================================================
-- 5. HARDENING RLS TABEL public.subscription_histories
-- ============================================================================
ALTER TABLE public.subscription_histories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view subscription_histories" ON public.subscription_histories;
DROP POLICY IF EXISTS "Admins can insert subscription_histories" ON public.subscription_histories;
DROP POLICY IF EXISTS "Admins can update subscription_histories" ON public.subscription_histories;

CREATE POLICY "Admins can view subscription_histories"
    ON public.subscription_histories
    FOR SELECT
    TO authenticated
    USING (
      public.is_admin()
      OR partner_id = public.get_current_partner_id()
      OR EXISTS (
        SELECT 1 FROM public.businesses b
        WHERE b.id = subscription_histories.business_id
          AND b.owner_user_id = auth.uid()
      )
    );

CREATE POLICY "Admins can insert subscription_histories"
    ON public.subscription_histories
    FOR INSERT
    TO authenticated
    WITH CHECK (
      public.is_admin()
      OR partner_id = public.get_current_partner_id()
    );

CREATE POLICY "Admins can update subscription_histories"
    ON public.subscription_histories
    FOR UPDATE
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================================
-- 6. HARDENING RLS TABEL public.partner_commissions & partner_payouts
-- ============================================================================
ALTER TABLE public.partner_commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_payouts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view partner_commissions" ON public.partner_commissions;
DROP POLICY IF EXISTS "Admins can insert partner_commissions" ON public.partner_commissions;
DROP POLICY IF EXISTS "Admins can update partner_commissions" ON public.partner_commissions;

CREATE POLICY "Admins can view partner_commissions"
    ON public.partner_commissions
    FOR SELECT
    TO authenticated
    USING (
      public.is_admin()
      OR partner_id = public.get_current_partner_id()
    );

CREATE POLICY "Admins can insert partner_commissions"
    ON public.partner_commissions
    FOR INSERT
    TO authenticated
    WITH CHECK (public.is_admin());

CREATE POLICY "Admins can update partner_commissions"
    ON public.partner_commissions
    FOR UPDATE
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can view partner_payouts" ON public.partner_payouts;
DROP POLICY IF EXISTS "Admins can insert partner_payouts" ON public.partner_payouts;
DROP POLICY IF EXISTS "Admins can update partner_payouts" ON public.partner_payouts;

CREATE POLICY "Admins can view partner_payouts"
    ON public.partner_payouts
    FOR SELECT
    TO authenticated
    USING (
      public.is_admin()
      OR partner_id = public.get_current_partner_id()
    );

CREATE POLICY "Admins can insert partner_payouts"
    ON public.partner_payouts
    FOR INSERT
    TO authenticated
    WITH CHECK (public.is_admin());

CREATE POLICY "Admins can update partner_payouts"
    ON public.partner_payouts
    FOR UPDATE
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());
