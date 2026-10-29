-- ====================================================================
-- Migration: Add Admin Write Policies for Master Catalog
-- Date: 2026-05-21
-- Allows Admins to insert, update, and delete products in master_catalog
-- ====================================================================

-- 1. Insert policy for admins
DROP POLICY IF EXISTS "Allow admins to insert master_catalog" ON public.master_catalog;
CREATE POLICY "Allow admins to insert master_catalog" ON public.master_catalog
    FOR INSERT TO authenticated
    WITH CHECK (
        public.is_admin()
    );

-- 2. Update policy for admins
DROP POLICY IF EXISTS "Allow admins to update master_catalog" ON public.master_catalog;
CREATE POLICY "Allow admins to update master_catalog" ON public.master_catalog
    FOR UPDATE TO authenticated
    USING (
        public.is_admin()
    )
    WITH CHECK (
        public.is_admin()
    );

-- 3. Delete policy for admins
DROP POLICY IF EXISTS "Allow admins to delete master_catalog" ON public.master_catalog;
CREATE POLICY "Allow admins to delete master_catalog" ON public.master_catalog
    FOR DELETE TO authenticated
    USING (
        public.is_admin()
    );
