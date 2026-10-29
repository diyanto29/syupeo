-- Migration: Create system_announcements table for Super Admin broadcasts
-- Target criteria:
--   'all'              : Muncul di semua merchant/toko
--   'missing_location' : Hanya muncul di toko yang belum punya koordinat GPS
--   'free_plan'        : Hanya toko paket Free
--   'pro_plan'         : Hanya toko paket Pro/Bisnis

CREATE TABLE IF NOT EXISTS public.system_announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    badge_text TEXT NOT NULL DEFAULT 'PENGUMUMAN FITUR BARU',
    type TEXT NOT NULL DEFAULT 'feature', -- 'feature', 'info', 'warning', 'promo'
    target_criteria TEXT NOT NULL DEFAULT 'missing_location', -- 'all', 'missing_location', 'free_plan', 'pro_plan'
    action_type TEXT NOT NULL DEFAULT 'route', -- 'route', 'url'
    action_target TEXT NOT NULL DEFAULT 'businessProfileEdit', -- route name or external url
    action_label TEXT NOT NULL DEFAULT 'Atur Lokasi Sekarang',
    secondary_action_target TEXT DEFAULT 'outletManagement',
    secondary_action_label TEXT DEFAULT 'Kelola Outlet',
    is_active BOOLEAN NOT NULL DEFAULT true,
    starts_at TIMESTAMPTZ DEFAULT now(),
    ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for fast active announcements lookup
CREATE INDEX IF NOT EXISTS idx_system_announcements_active 
ON public.system_announcements (is_active, starts_at, ends_at);

-- Enable RLS
ALTER TABLE public.system_announcements ENABLE ROW LEVEL SECURITY;

-- 1. Read policy for authenticated users (Kasir / Merchant / Owner)
DROP POLICY IF EXISTS "Authenticated users can read active announcements" ON public.system_announcements;
CREATE POLICY "Authenticated users can read active announcements" 
ON public.system_announcements 
FOR SELECT 
TO authenticated 
USING (
    is_active = true 
    AND (starts_at IS NULL OR starts_at <= now())
    AND (ends_at IS NULL OR ends_at >= now())
);

-- 2. Full access policy for Super Admin & Admin users
DROP POLICY IF EXISTS "Admins have full access to system_announcements" ON public.system_announcements;
CREATE POLICY "Admins have full access to system_announcements" 
ON public.system_announcements 
FOR ALL 
TO authenticated 
USING (
    public.is_admin() 
    OR EXISTS (
        SELECT 1 FROM public.admin_users au 
        WHERE au.email = auth.jwt() ->> 'email' 
        AND au.is_active = true
    )
)
WITH CHECK (
    public.is_admin() 
    OR EXISTS (
        SELECT 1 FROM public.admin_users au 
        WHERE au.email = auth.jwt() ->> 'email' 
        AND au.is_active = true
    )
);

-- Seed initial announcement: Pin Titik Lokasi & Direktori Web
INSERT INTO public.system_announcements (
    title,
    message,
    badge_text,
    type,
    target_criteria,
    action_type,
    action_target,
    action_label,
    secondary_action_target,
    secondary_action_label,
    is_active
) VALUES (
    'Pin Titik Lokasi & Direktori Web Online',
    'Toko Anda belum mengatur titik koordinat GPS. Kunci lokasi gerai Anda sekarang agar otomatis tampil di peta web direktori toko aktif dan siap menghitung radius delivery pelanggan.',
    'PENGUMUMAN FITUR BARU',
    'feature',
    'missing_location',
    'route',
    'businessProfileEdit',
    'Atur Lokasi Sekarang',
    'outletManagement',
    'Kelola Outlet',
    true
) ON CONFLICT DO NOTHING;
