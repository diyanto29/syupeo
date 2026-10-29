-- Migration: Create app_licenses table to record generated serial keys for BatiKu, KosanKu, and ManggoPOS
CREATE TABLE IF NOT EXISTS public.app_licenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    app_code VARCHAR(50) NOT NULL, -- 'BATIKU', 'KOSANKU', 'MANGGOPOS', 'CUSTOM'
    app_name VARCHAR(100) NOT NULL,
    device_id VARCHAR(100) NOT NULL,
    serial_key VARCHAR(100) NOT NULL,
    buyer_name VARCHAR(150),
    platform VARCHAR(50) DEFAULT 'Direct', -- 'Shopee', 'Tokopedia', 'WhatsApp', 'Direct'
    notes TEXT,
    -- Referral & Komisi Mitra
    license_price NUMERIC DEFAULT 0,
    referrer_name VARCHAR(150),
    commission_amount NUMERIC DEFAULT 0,
    commission_status VARCHAR(50) DEFAULT 'unpaid', -- 'unpaid', 'paid', 'none'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- If table already exists, alter to add columns safely
ALTER TABLE public.app_licenses ADD COLUMN IF NOT EXISTS license_price NUMERIC DEFAULT 0;
ALTER TABLE public.app_licenses ADD COLUMN IF NOT EXISTS referrer_name VARCHAR(150);
ALTER TABLE public.app_licenses ADD COLUMN IF NOT EXISTS commission_amount NUMERIC DEFAULT 0;
ALTER TABLE public.app_licenses ADD COLUMN IF NOT EXISTS commission_status VARCHAR(50) DEFAULT 'unpaid';

-- Indexes for fast querying
CREATE INDEX IF NOT EXISTS idx_app_licenses_app_code ON public.app_licenses(app_code);
CREATE INDEX IF NOT EXISTS idx_app_licenses_device_id ON public.app_licenses(device_id);
CREATE INDEX IF NOT EXISTS idx_app_licenses_referrer_name ON public.app_licenses(referrer_name);
CREATE INDEX IF NOT EXISTS idx_app_licenses_created_at ON public.app_licenses(created_at DESC);

-- Enable RLS
ALTER TABLE public.app_licenses ENABLE ROW LEVEL SECURITY;

-- Drop existing policies first to prevent "policy already exists" error
DROP POLICY IF EXISTS "Admins can view app licenses" ON public.app_licenses;
DROP POLICY IF EXISTS "Admins can insert app licenses" ON public.app_licenses;
DROP POLICY IF EXISTS "Admins can update app licenses" ON public.app_licenses;
DROP POLICY IF EXISTS "Admins can delete app licenses" ON public.app_licenses;

-- Re-create policies cleanly
CREATE POLICY "Admins can view app licenses"
    ON public.app_licenses
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Admins can insert app licenses"
    ON public.app_licenses
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Admins can update app licenses"
    ON public.app_licenses
    FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Admins can delete app licenses"
    ON public.app_licenses
    FOR DELETE
    TO authenticated
    USING (true);
