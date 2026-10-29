-- Migration: Mini CRM (Leads, Activities & Quotations System)
-- Date: 2026-10-10

-- 1. Table: leads (Prospek Toko & Calon Klien)
CREATE TABLE IF NOT EXISTS public.leads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id UUID REFERENCES public.partners(id) ON DELETE SET NULL,
    business_name VARCHAR(150) NOT NULL,
    contact_name VARCHAR(150),
    phone VARCHAR(50),
    email VARCHAR(150),
    city VARCHAR(100),
    business_type VARCHAR(50) DEFAULT 'fnb', -- 'fnb', 'retail', 'service', 'other'
    status VARCHAR(50) DEFAULT 'new', -- 'new', 'contacted', 'demo', 'quoted', 'won', 'lost'
    estimated_deal_value NUMERIC DEFAULT 399000, -- default 1 tahun pro
    notes TEXT,
    lost_reason TEXT,
    converted_business_id UUID REFERENCES public.businesses(id) ON DELETE SET NULL,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for leads
CREATE INDEX IF NOT EXISTS idx_leads_partner ON public.leads(partner_id);
CREATE INDEX IF NOT EXISTS idx_leads_status ON public.leads(status);
CREATE INDEX IF NOT EXISTS idx_leads_phone ON public.leads(phone);
CREATE INDEX IF NOT EXISTS idx_leads_created_at ON public.leads(created_at DESC);

-- 2. Table: lead_activities (Catatan Interaksi & Follow-up)
CREATE TABLE IF NOT EXISTS public.lead_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
    partner_id UUID REFERENCES public.partners(id) ON DELETE SET NULL,
    activity_type VARCHAR(50) NOT NULL DEFAULT 'whatsapp', -- 'whatsapp', 'call', 'meeting', 'demo', 'note'
    notes TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lead_activities_lead ON public.lead_activities(lead_id);
CREATE INDEX IF NOT EXISTS idx_lead_activities_created_at ON public.lead_activities(created_at DESC);

-- 3. Table: quotations (Surat Penawaran Harga Resmi)
CREATE TABLE IF NOT EXISTS public.quotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lead_id UUID REFERENCES public.leads(id) ON DELETE SET NULL,
    partner_id UUID REFERENCES public.partners(id) ON DELETE SET NULL,
    quote_number VARCHAR(50) NOT NULL UNIQUE,
    client_name VARCHAR(150) NOT NULL,
    client_business_name VARCHAR(150) NOT NULL,
    client_phone VARCHAR(50),
    items JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of { description, qty, unit_price, total_price }
    subtotal NUMERIC NOT NULL DEFAULT 0,
    discount_amount NUMERIC DEFAULT 0,
    final_amount NUMERIC NOT NULL DEFAULT 0,
    valid_until DATE,
    status VARCHAR(50) DEFAULT 'sent', -- 'draft', 'sent', 'accepted', 'rejected', 'expired'
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quotations_lead ON public.quotations(lead_id);
CREATE INDEX IF NOT EXISTS idx_quotations_partner ON public.quotations(partner_id);
CREATE INDEX IF NOT EXISTS idx_quotations_quote_number ON public.quotations(quote_number);
CREATE INDEX IF NOT EXISTS idx_quotations_created_at ON public.quotations(created_at DESC);

-- Enable RLS
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quotations ENABLE ROW LEVEL SECURITY;

-- Clean recreate policies for Authenticated Users / Admins
DROP POLICY IF EXISTS "Admins can view leads" ON public.leads;
DROP POLICY IF EXISTS "Admins can insert leads" ON public.leads;
DROP POLICY IF EXISTS "Admins can update leads" ON public.leads;
DROP POLICY IF EXISTS "Admins can delete leads" ON public.leads;

CREATE POLICY "Admins can view leads" ON public.leads FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can insert leads" ON public.leads FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Admins can update leads" ON public.leads FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Admins can delete leads" ON public.leads FOR DELETE TO authenticated USING (true);

DROP POLICY IF EXISTS "Admins can view lead_activities" ON public.lead_activities;
DROP POLICY IF EXISTS "Admins can insert lead_activities" ON public.lead_activities;
DROP POLICY IF EXISTS "Admins can update lead_activities" ON public.lead_activities;
DROP POLICY IF EXISTS "Admins can delete lead_activities" ON public.lead_activities;

CREATE POLICY "Admins can view lead_activities" ON public.lead_activities FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can insert lead_activities" ON public.lead_activities FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Admins can update lead_activities" ON public.lead_activities FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Admins can delete lead_activities" ON public.lead_activities FOR DELETE TO authenticated USING (true);

DROP POLICY IF EXISTS "Admins can view quotations" ON public.quotations;
DROP POLICY IF EXISTS "Admins can insert quotations" ON public.quotations;
DROP POLICY IF EXISTS "Admins can update quotations" ON public.quotations;
DROP POLICY IF EXISTS "Admins can delete quotations" ON public.quotations;

CREATE POLICY "Admins can view quotations" ON public.quotations FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can insert quotations" ON public.quotations FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Admins can update quotations" ON public.quotations FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Admins can delete quotations" ON public.quotations FOR DELETE TO authenticated USING (true);
