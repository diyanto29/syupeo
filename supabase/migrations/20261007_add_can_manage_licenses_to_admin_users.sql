-- Migration: Add can_manage_licenses permission column to admin_users table
ALTER TABLE public.admin_users 
ADD COLUMN IF NOT EXISTS can_manage_licenses BOOLEAN DEFAULT false;

-- Update super_admin to have can_manage_licenses = true
UPDATE public.admin_users 
SET can_manage_licenses = true 
WHERE role = 'super_admin' OR LOWER(email) = 'diyanto2911@gmail.com';
