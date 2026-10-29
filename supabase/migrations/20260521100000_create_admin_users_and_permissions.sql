-- ====================================================================
-- Migration: Create admin_users table and permissions for Admin Web
-- Date: 2026-05-21
-- Allows Super Admin to grant access to other team members via Admin Web
-- ====================================================================

CREATE TABLE IF NOT EXISTS public.admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  role TEXT NOT NULL DEFAULT 'admin' CHECK (role IN ('super_admin', 'admin')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- Index on lower(email)
CREATE INDEX IF NOT EXISTS idx_admin_users_email_lower ON public.admin_users (LOWER(email));

-- Insert default master super admin
INSERT INTO public.admin_users (email, name, role, is_active)
VALUES ('diyanto2911@gmail.com', 'Diyanto (Super Admin)', 'super_admin', true)
ON CONFLICT (email) DO UPDATE 
SET role = 'super_admin', is_active = true;

-- Helper function to check if current user is an active admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN (
    LOWER(auth.jwt() ->> 'email') = 'diyanto2911@gmail.com'
    OR EXISTS (
      SELECT 1 FROM public.admin_users
      WHERE LOWER(email) = LOWER(auth.jwt() ->> 'email')
        AND is_active = true
    )
  );
END;
$$;

-- Enable RLS on admin_users
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;

-- 1. SELECT policy: Active admins can view all, users can view their own record to verify access
DROP POLICY IF EXISTS "Allow admins to select admin_users" ON public.admin_users;
CREATE POLICY "Allow admins to select admin_users" ON public.admin_users
FOR SELECT TO authenticated
USING (
  public.is_admin()
  OR LOWER(email) = LOWER(auth.jwt() ->> 'email')
);

-- 2. INSERT policy: Only active admins can add new admins
DROP POLICY IF EXISTS "Allow admins to insert admin_users" ON public.admin_users;
CREATE POLICY "Allow admins to insert admin_users" ON public.admin_users
FOR INSERT TO authenticated
WITH CHECK (
  public.is_admin()
);

-- 3. UPDATE policy: Only active admins can update admins
DROP POLICY IF EXISTS "Allow admins to update admin_users" ON public.admin_users;
CREATE POLICY "Allow admins to update admin_users" ON public.admin_users
FOR UPDATE TO authenticated
USING (
  public.is_admin()
)
WITH CHECK (
  public.is_admin()
);

-- 4. DELETE policy: Only active admins can delete admins (and master email cannot be deleted)
DROP POLICY IF EXISTS "Allow admins to delete admin_users" ON public.admin_users;
CREATE POLICY "Allow admins to delete admin_users" ON public.admin_users
FOR DELETE TO authenticated
USING (
  public.is_admin()
  AND LOWER(email) <> 'diyanto2911@gmail.com'
);

-- 5. Update RLS policies on businesses table to use public.is_admin()
DROP POLICY IF EXISTS "Allow super admin to select all businesses" ON public.businesses;
CREATE POLICY "Allow super admin to select all businesses" ON public.businesses
FOR SELECT TO authenticated
USING (
  public.is_admin()
  OR owner_user_id = auth.uid()
);

DROP POLICY IF EXISTS "Allow super admin to update all businesses" ON public.businesses;
CREATE POLICY "Allow super admin to update all businesses" ON public.businesses
FOR UPDATE TO authenticated
USING (
  public.is_admin()
  OR owner_user_id = auth.uid()
)
WITH CHECK (
  public.is_admin()
  OR owner_user_id = auth.uid()
);

-- 6. Update RLS policies on profiles table to use public.is_admin()
DROP POLICY IF EXISTS "Allow super admin to select all profiles" ON public.profiles;
CREATE POLICY "Allow super admin to select all profiles" ON public.profiles
FOR SELECT TO authenticated
USING (
  public.is_admin()
  OR id = auth.uid()
);
