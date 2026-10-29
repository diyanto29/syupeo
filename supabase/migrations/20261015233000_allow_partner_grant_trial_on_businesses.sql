-- ====================================================================
-- Migration: Allow Partners to Grant PRO Trial on Referred Businesses
-- Date: 2026-10-15
-- ====================================================================

-- 1. Businesses: Allow partners to update their own referred businesses (for granting trial)
DROP POLICY IF EXISTS "Partners can update referred businesses" ON public.businesses;
CREATE POLICY "Partners can update referred businesses" ON public.businesses
  FOR UPDATE TO authenticated
  USING (
    public.is_admin() OR referred_by_partner_id = public.get_current_partner_id()
  )
  WITH CHECK (
    public.is_admin() OR referred_by_partner_id = public.get_current_partner_id()
  );

-- 2. Businesses: Allow partners to insert businesses during lead conversion
DROP POLICY IF EXISTS "Partners can insert referred businesses" ON public.businesses;
CREATE POLICY "Partners can insert referred businesses" ON public.businesses
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_admin()
    OR owner_user_id = auth.uid()
    OR referred_by_partner_id = public.get_current_partner_id()
  );

-- 3. Subscription Plans: Ensure partners can view active plans to assign trial limits
DROP POLICY IF EXISTS "Allow authenticated to select plans" ON public.subscription_plans;
CREATE POLICY "Allow authenticated to select plans" ON public.subscription_plans
  FOR SELECT TO authenticated USING (true);
