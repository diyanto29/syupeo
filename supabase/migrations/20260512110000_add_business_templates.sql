-- Migration: Add Business Type Templates for Dynamic Feature Mapping
-- Date: 2026-05-12

CREATE TABLE IF NOT EXISTS public.business_type_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE, -- e.g., 'Retail', 'F&B', 'Service'
    code TEXT NOT NULL UNIQUE, -- e.g., 'retail', 'fnb', 'service'
    description TEXT,
    icon_name TEXT, -- Material icon name or local asset path
    default_enabled_features JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Seed initial templates
INSERT INTO public.business_type_templates (name, code, description, icon_name, default_enabled_features)
VALUES 
('Food & Beverage', 'fnb', 'Template for cafes, restaurants, and bars', 'restaurant_rounded', '["transaction", "order_mgmt", "menu_mgmt", "table_mgmt", "kitchen_kds", "reports"]'),
('Retail', 'retail', 'Template for shops and boutiques', 'shopping_bag_rounded', '["transaction", "menu_mgmt", "inventory", "reports"]'),
('Layanan / Service', 'service', 'Template for salons, barbershops, and consultants', 'handyman_rounded', '["transaction", "order_mgmt", "reports"]'),
('General / All Features', 'general', 'Template with all features enabled', 'apps_rounded', '["transaction", "order_mgmt", "menu_mgmt", "table_mgmt", "kitchen_kds", "inventory", "qr_order", "reports"]')
ON CONFLICT (code) DO UPDATE 
SET default_enabled_features = EXCLUDED.default_enabled_features,
    icon_name = EXCLUDED.icon_name,
    description = EXCLUDED.description;

-- Ensure businesses table has the columns (User added them in model, let's make sure they are in DB)
ALTER TABLE public.businesses 
ADD COLUMN IF NOT EXISTS business_type TEXT,
ADD COLUMN IF NOT EXISTS enabled_features JSONB NOT NULL DEFAULT '[]'::jsonb;

-- RLS for templates
ALTER TABLE public.business_type_templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all to read templates" ON public.business_type_templates FOR SELECT TO authenticated USING (true);

-- Policy for managing templates (Restricted to specific admin email for now)
CREATE POLICY "Allow admin to manage templates" ON public.business_type_templates 
FOR ALL TO authenticated 
USING (auth.jwt() ->> 'email' = 'diyanto2911@gmail.com')
WITH CHECK (auth.jwt() ->> 'email' = 'diyanto2911@gmail.com');
