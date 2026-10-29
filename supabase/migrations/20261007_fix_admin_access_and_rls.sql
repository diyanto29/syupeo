-- ====================================================================
-- Migration: Fix Admin RLS Access for All Admin Users
-- Date: 2026-10-07
-- Enables all registered & active admins to view Businesses, Profiles,
-- Orders, Order Payments, Order Items, and Outlets.
-- ====================================================================

-- 1. Upgrade public.is_admin() to be bulletproof (with auth.users fallback)
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

  -- Get email from JWT claim, or fallback to auth.users table
  v_email := LOWER(COALESCE(
    auth.jwt() ->> 'email',
    (SELECT email FROM auth.users WHERE id = v_uid)
  ));

  IF v_email IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Master super admin email check
  IF v_email = 'diyanto2911@gmail.com' THEN
    RETURN TRUE;
  END IF;

  -- Check admin_users table for active admin
  RETURN EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE LOWER(email) = v_email
      AND is_active = true
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, anon;

-- 2. Businesses: Allow ALL active admins to SELECT and UPDATE
DROP POLICY IF EXISTS "Allow super admin to select all businesses" ON public.businesses;
DROP POLICY IF EXISTS "Allow admins to select all businesses" ON public.businesses;
CREATE POLICY "Allow admins to select all businesses" ON public.businesses
FOR SELECT TO authenticated
USING (
  public.is_admin() OR owner_user_id = auth.uid()
);

DROP POLICY IF EXISTS "Allow super admin to update all businesses" ON public.businesses;
DROP POLICY IF EXISTS "Allow admins to update all businesses" ON public.businesses;
CREATE POLICY "Allow admins to update all businesses" ON public.businesses
FOR UPDATE TO authenticated
USING (
  public.is_admin() OR owner_user_id = auth.uid()
)
WITH CHECK (
  public.is_admin() OR owner_user_id = auth.uid()
);

-- 3. Profiles: Allow ALL active admins to SELECT all profiles
DROP POLICY IF EXISTS "Allow super admin to select all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Allow admins to select all profiles" ON public.profiles;
CREATE POLICY "Allow admins to select all profiles" ON public.profiles
FOR SELECT TO authenticated
USING (
  public.is_admin() OR id = auth.uid()
);

-- 4. Orders: Allow ALL active admins to SELECT all orders
DROP POLICY IF EXISTS "Allow admins to select all orders" ON public.orders;
CREATE POLICY "Allow admins to select all orders" ON public.orders
FOR SELECT TO authenticated
USING (
  public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = orders.outlet_id
      AND (
        public.is_business_owner(o.business_id)
        OR public.is_business_member(o.business_id, auth.uid())
      )
  )
);

-- 5. Order Payments: Allow ALL active admins to SELECT all order_payments
DROP POLICY IF EXISTS "Allow admins to select all order_payments" ON public.order_payments;
CREATE POLICY "Allow admins to select all order_payments" ON public.order_payments
FOR SELECT TO authenticated
USING (
  public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.orders ord
    JOIN public.outlets o ON o.id = ord.outlet_id
    WHERE ord.id = order_payments.order_id
      AND (
        public.is_business_owner(o.business_id)
        OR public.is_business_member(o.business_id, auth.uid())
      )
  )
);

-- 6. Order Items: Allow ALL active admins to SELECT all order_items
DROP POLICY IF EXISTS "Allow admins to select all order_items" ON public.order_items;
CREATE POLICY "Allow admins to select all order_items" ON public.order_items
FOR SELECT TO authenticated
USING (
  public.is_admin()
  OR EXISTS (
    SELECT 1 FROM public.orders ord
    JOIN public.outlets o ON o.id = ord.outlet_id
    WHERE ord.id = order_items.order_id
      AND (
        public.is_business_owner(o.business_id)
        OR public.is_business_member(o.business_id, auth.uid())
      )
  )
);

-- 7. Outlets: Allow ALL active admins to SELECT all outlets
DROP POLICY IF EXISTS "Allow admins to select all outlets" ON public.outlets;
CREATE POLICY "Allow admins to select all outlets" ON public.outlets
FOR SELECT TO authenticated
USING (
  public.is_admin()
  OR public.is_business_owner(outlets.business_id)
  OR public.is_business_member(outlets.business_id, auth.uid())
);
