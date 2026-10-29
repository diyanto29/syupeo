-- ====================================================================
-- Migration: Add Partner/Marketer Role to Admin Users and Access Policies
-- Date: 2026-10-15
-- ====================================================================

-- 1. Alter admin_users table to allow 'partner' role, add user_id, and reference partner_id
ALTER TABLE public.admin_users
  DROP CONSTRAINT IF EXISTS admin_users_role_check;

ALTER TABLE public.admin_users
  ADD CONSTRAINT admin_users_role_check CHECK (role IN ('super_admin', 'admin', 'partner')),
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS partner_id UUID REFERENCES public.partners(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_admin_users_user_id ON public.admin_users(user_id);
CREATE INDEX IF NOT EXISTS idx_admin_users_partner_id ON public.admin_users(partner_id);

-- Auto-populate user_id from auth.users for existing admin records
UPDATE public.admin_users au
SET user_id = u.id
FROM auth.users u
WHERE LOWER(au.email) = LOWER(u.email)
  AND au.user_id IS NULL;

-- 2. Helper function to safely get authenticated user email via SECURITY DEFINER
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

-- 3. Helper function to get current partner ID for the authenticated user
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

-- 4. Update is_admin() function to ONLY recognize super_admin or admin as full-access admins
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
  v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN FALSE;
  END IF;

  v_email := public.get_auth_email();

  -- Master super admin email check (Always TRUE for master admin)
  IF v_email = 'diyanto2911@gmail.com' THEN
    RETURN TRUE;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE (
        (v_email IS NOT NULL AND LOWER(email) = v_email)
        OR (user_id IS NOT NULL AND user_id = v_uid)
      )
      AND is_active = true
      AND role IN ('super_admin', 'admin')
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, anon;

-- 4b. Ensure partners and admins can query their own admin_users record safely without touching auth.users directly
DROP POLICY IF EXISTS "Allow admins to select admin_users" ON public.admin_users;
DROP POLICY IF EXISTS "Allow partners and admins to select admin_users" ON public.admin_users;
CREATE POLICY "Allow partners and admins to select admin_users" ON public.admin_users
FOR SELECT TO authenticated
USING (
  public.is_admin()
  OR (user_id IS NOT NULL AND user_id = auth.uid())
  OR LOWER(email) = public.get_auth_email()
);

-- 4. RLS for Partner Self-Access to Leads, Quotations, Commissions, Payouts
-- Drop existing broad policies and make them role-aware if needed
DROP POLICY IF EXISTS "Partners can view own leads" ON public.leads;
DROP POLICY IF EXISTS "Partners can insert own leads" ON public.leads;
DROP POLICY IF EXISTS "Partners can update own leads" ON public.leads;

CREATE POLICY "Partners can view own leads" ON public.leads
  FOR SELECT TO authenticated
  USING (
    public.is_admin() OR partner_id = public.get_current_partner_id()
  );

CREATE POLICY "Partners can insert own leads" ON public.leads
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_admin() OR partner_id = public.get_current_partner_id()
  );

CREATE POLICY "Partners can update own leads" ON public.leads
  FOR UPDATE TO authenticated
  USING (
    public.is_admin() OR partner_id = public.get_current_partner_id()
  )
  WITH CHECK (
    public.is_admin() OR partner_id = public.get_current_partner_id()
  );

-- Quotations
DROP POLICY IF EXISTS "Partners can view own quotations" ON public.quotations;
DROP POLICY IF EXISTS "Partners can insert own quotations" ON public.quotations;
DROP POLICY IF EXISTS "Partners can update own quotations" ON public.quotations;

CREATE POLICY "Partners can view own quotations" ON public.quotations
  FOR SELECT TO authenticated
  USING (
    public.is_admin() OR partner_id = public.get_current_partner_id()
  );

CREATE POLICY "Partners can insert own quotations" ON public.quotations
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_admin() OR partner_id = public.get_current_partner_id()
  );

CREATE POLICY "Partners can update own quotations" ON public.quotations
  FOR UPDATE TO authenticated
  USING (
    public.is_admin() OR partner_id = public.get_current_partner_id()
  )
  WITH CHECK (
    public.is_admin() OR partner_id = public.get_current_partner_id()
  );

-- Partner Commissions
DROP POLICY IF EXISTS "Partners can view own commissions" ON public.partner_commissions;
CREATE POLICY "Partners can view own commissions" ON public.partner_commissions
  FOR SELECT TO authenticated
  USING (
    public.is_admin() OR partner_id = public.get_current_partner_id()
  );

-- Partner Payouts
DROP POLICY IF EXISTS "Partners can view own payouts" ON public.partner_payouts;
DROP POLICY IF EXISTS "Partners can insert own payouts" ON public.partner_payouts;

CREATE POLICY "Partners can view own payouts" ON public.partner_payouts
  FOR SELECT TO authenticated
  USING (
    public.is_admin() OR partner_id = public.get_current_partner_id()
  );

CREATE POLICY "Partners can insert own payouts" ON public.partner_payouts
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_admin() OR partner_id = public.get_current_partner_id()
  );

-- Businesses (partners can read their referred businesses)
DROP POLICY IF EXISTS "Partners can view referred businesses" ON public.businesses;
CREATE POLICY "Partners can view referred businesses" ON public.businesses
  FOR SELECT TO authenticated
  USING (
    public.is_admin() OR referred_by_partner_id = public.get_current_partner_id()
  );

-- Allow partners to view profiles of referred business owners
DROP POLICY IF EXISTS "Partners can view profiles of referred businesses" ON public.profiles;
CREATE POLICY "Partners can view profiles of referred businesses" ON public.profiles
  FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.businesses b
      WHERE b.owner_user_id = profiles.id
        AND b.referred_by_partner_id = public.get_current_partner_id()
    )
  );
