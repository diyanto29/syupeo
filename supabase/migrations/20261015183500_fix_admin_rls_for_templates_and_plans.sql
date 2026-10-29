-- ============================================================================
-- Migration: Fix Admin RLS for business_type_templates and subscription_plans
-- Uses public.is_admin() (SECURITY DEFINER) to avoid direct auth.users permission errors
-- ============================================================================

-- 1. Business Type Templates
DROP POLICY IF EXISTS "Allow admin to manage templates" ON public.business_type_templates;
DROP POLICY IF EXISTS "Allow all to read templates" ON public.business_type_templates;

-- Read: Anyone authenticated or anonymous can read template definitions
CREATE POLICY "Allow all to read templates" 
ON public.business_type_templates 
FOR SELECT 
TO authenticated, anon 
USING (true);

-- Manage: Only admins verified via security-definer function public.is_admin()
CREATE POLICY "Allow admin to manage templates" 
ON public.business_type_templates 
FOR ALL 
TO authenticated 
USING (
  public.is_admin()
)
WITH CHECK (
  public.is_admin()
);

-- 2. Subscription Plans
DROP POLICY IF EXISTS "Allow super admin all on subscription_plans" ON public.subscription_plans;
DROP POLICY IF EXISTS "Allow admin to manage subscription_plans" ON public.subscription_plans;
DROP POLICY IF EXISTS "Allow all to read plans" ON public.subscription_plans;

-- Read: Anyone authenticated or anonymous can view plans
CREATE POLICY "Allow all to read plans" 
ON public.subscription_plans 
FOR SELECT 
TO authenticated, anon 
USING (true);

-- Manage: Only admins verified via security-definer function public.is_admin()
CREATE POLICY "Allow admin to manage subscription_plans" 
ON public.subscription_plans 
FOR ALL 
TO authenticated 
USING (
  public.is_admin()
)
WITH CHECK (
  public.is_admin()
);
