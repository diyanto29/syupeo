-- Migration: Grant Super Admin Access to Businesses and Profiles
-- Date: 2026-05-12

-- 1. Policy for Super Admin to SELECT all businesses
DROP POLICY IF EXISTS "Allow super admin to select all businesses" ON public.businesses;
CREATE POLICY "Allow super admin to select all businesses" ON public.businesses
FOR SELECT TO authenticated
USING (
    auth.jwt() ->> 'email' = 'diyanto2911@gmail.com'
    OR owner_user_id = auth.uid()
);

-- 2. Policy for Super Admin to UPDATE all businesses
DROP POLICY IF EXISTS "Allow super admin to update all businesses" ON public.businesses;
CREATE POLICY "Allow super admin to update all businesses" ON public.businesses
FOR UPDATE TO authenticated
USING (
    auth.jwt() ->> 'email' = 'diyanto2911@gmail.com'
    OR owner_user_id = auth.uid()
)
WITH CHECK (
    auth.jwt() ->> 'email' = 'diyanto2911@gmail.com'
    OR owner_user_id = auth.uid()
);

-- 3. Policy for Super Admin to SELECT all profiles
DROP POLICY IF EXISTS "Allow super admin to select all profiles" ON public.profiles;
CREATE POLICY "Allow super admin to select all profiles" ON public.profiles
FOR SELECT TO authenticated
USING (
    auth.jwt() ->> 'email' = 'diyanto2911@gmail.com'
    OR id = auth.uid()
);
