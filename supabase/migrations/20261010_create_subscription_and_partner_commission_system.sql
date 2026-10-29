-- Migration: Subscription Management, Activation History & Partner Referral Commission System
-- Date: 2026-10-10

-- 1. Table: partners (Teman / Mitra / Sales Affiliate)
CREATE TABLE IF NOT EXISTS public.partners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    phone VARCHAR(50),
    email VARCHAR(150),
    referral_code VARCHAR(50) UNIQUE,
    commission_rate NUMERIC DEFAULT 20.00, -- Default 20%
    bank_name VARCHAR(100),
    bank_account_number VARCHAR(100),
    bank_account_holder VARCHAR(150),
    status VARCHAR(50) DEFAULT 'active', -- 'active', 'inactive'
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for partners
CREATE INDEX IF NOT EXISTS idx_partners_referral_code ON public.partners(referral_code);
CREATE INDEX IF NOT EXISTS idx_partners_status ON public.partners(status);

-- 2. Alter businesses to attach referring partner
ALTER TABLE public.businesses 
ADD COLUMN IF NOT EXISTS referred_by_partner_id UUID REFERENCES public.partners(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_businesses_referred_by_partner ON public.businesses(referred_by_partner_id);

-- 3. Table: subscription_histories (Riwayat Aktivasi, Perpanjangan & Trial)
CREATE TABLE IF NOT EXISTS public.subscription_histories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    plan_id UUID REFERENCES public.subscription_plans(id) ON DELETE SET NULL,
    action_type VARCHAR(50) NOT NULL, -- 'trial', 'new', 'renewal', 'upgrade', 'manual_admin'
    duration_type VARCHAR(50) NOT NULL DEFAULT 'months', -- 'days', 'months', 'lifetime'
    duration_value INT NOT NULL DEFAULT 1,
    price_paid NUMERIC DEFAULT 0,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ, -- null for lifetime
    partner_id UUID REFERENCES public.partners(id) ON DELETE SET NULL,
    commission_rate NUMERIC DEFAULT 0,
    commission_amount NUMERIC DEFAULT 0,
    payment_status VARCHAR(50) DEFAULT 'paid', -- 'paid', 'free_trial', 'waived'
    payment_method VARCHAR(50) DEFAULT 'manual_transfer',
    notes TEXT,
    created_by_admin VARCHAR(150),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sub_histories_business ON public.subscription_histories(business_id);
CREATE INDEX IF NOT EXISTS idx_sub_histories_partner ON public.subscription_histories(partner_id);
CREATE INDEX IF NOT EXISTS idx_sub_histories_created_at ON public.subscription_histories(created_at DESC);

-- 4. Table: partner_commissions (Rincian Komisi Masuk Tiap Transaksi)
CREATE TABLE IF NOT EXISTS public.partner_commissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id UUID NOT NULL REFERENCES public.partners(id) ON DELETE CASCADE,
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    subscription_history_id UUID REFERENCES public.subscription_histories(id) ON DELETE CASCADE,
    subscription_amount NUMERIC NOT NULL DEFAULT 0,
    commission_rate NUMERIC NOT NULL DEFAULT 0,
    commission_amount NUMERIC NOT NULL DEFAULT 0,
    description TEXT,
    status VARCHAR(50) DEFAULT 'earned', -- 'earned', 'cancelled'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_partner_commissions_partner ON public.partner_commissions(partner_id);
CREATE INDEX IF NOT EXISTS idx_partner_commissions_business ON public.partner_commissions(business_id);
CREATE INDEX IF NOT EXISTS idx_partner_commissions_created_at ON public.partner_commissions(created_at DESC);

-- 5. Table: partner_payouts (Riwayat Penarikan / Transfer Saldo ke Rekening Teman)
CREATE TABLE IF NOT EXISTS public.partner_payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id UUID NOT NULL REFERENCES public.partners(id) ON DELETE CASCADE,
    amount NUMERIC NOT NULL DEFAULT 0,
    bank_name VARCHAR(100),
    bank_account_number VARCHAR(100),
    bank_account_holder VARCHAR(150),
    status VARCHAR(50) DEFAULT 'completed', -- 'completed', 'pending', 'rejected'
    reference_note TEXT,
    proof_url TEXT,
    processed_by VARCHAR(150),
    processed_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_partner_payouts_partner ON public.partner_payouts(partner_id);
CREATE INDEX IF NOT EXISTS idx_partner_payouts_created_at ON public.partner_payouts(created_at DESC);

-- Enable RLS on all newly created tables
ALTER TABLE public.partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_histories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_payouts ENABLE ROW LEVEL SECURITY;

-- Clean recreate policies for Authenticated Admins
DROP POLICY IF EXISTS "Admins can view partners" ON public.partners;
DROP POLICY IF EXISTS "Admins can insert partners" ON public.partners;
DROP POLICY IF EXISTS "Admins can update partners" ON public.partners;
DROP POLICY IF EXISTS "Admins can delete partners" ON public.partners;

CREATE POLICY "Admins can view partners" ON public.partners FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can insert partners" ON public.partners FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Admins can update partners" ON public.partners FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Admins can delete partners" ON public.partners FOR DELETE TO authenticated USING (true);

DROP POLICY IF EXISTS "Admins can view subscription_histories" ON public.subscription_histories;
DROP POLICY IF EXISTS "Admins can insert subscription_histories" ON public.subscription_histories;
DROP POLICY IF EXISTS "Admins can update subscription_histories" ON public.subscription_histories;

CREATE POLICY "Admins can view subscription_histories" ON public.subscription_histories FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can insert subscription_histories" ON public.subscription_histories FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Admins can update subscription_histories" ON public.subscription_histories FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Admins can view partner_commissions" ON public.partner_commissions;
DROP POLICY IF EXISTS "Admins can insert partner_commissions" ON public.partner_commissions;
DROP POLICY IF EXISTS "Admins can update partner_commissions" ON public.partner_commissions;

CREATE POLICY "Admins can view partner_commissions" ON public.partner_commissions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can insert partner_commissions" ON public.partner_commissions FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Admins can update partner_commissions" ON public.partner_commissions FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Admins can view partner_payouts" ON public.partner_payouts;
DROP POLICY IF EXISTS "Admins can insert partner_payouts" ON public.partner_payouts;
DROP POLICY IF EXISTS "Admins can update partner_payouts" ON public.partner_payouts;

CREATE POLICY "Admins can view partner_payouts" ON public.partner_payouts FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can insert partner_payouts" ON public.partner_payouts FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Admins can update partner_payouts" ON public.partner_payouts FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
