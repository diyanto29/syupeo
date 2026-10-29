-- Migration: Add Dynamic Limits and Ad Control
-- Date: 2026-05-12

-- Add limit columns to business_type_templates
ALTER TABLE public.business_type_templates 
ADD COLUMN IF NOT EXISTS max_transactions INTEGER DEFAULT 100,
ADD COLUMN IF NOT EXISTS max_products INTEGER DEFAULT 50,
ADD COLUMN IF NOT EXISTS max_outlets INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS show_ads BOOLEAN DEFAULT true;

-- Add limit columns to businesses (as overrides)
ALTER TABLE public.businesses 
ADD COLUMN IF NOT EXISTS max_transactions INTEGER,
ADD COLUMN IF NOT EXISTS max_products INTEGER,
ADD COLUMN IF NOT EXISTS max_outlets INTEGER,
ADD COLUMN IF NOT EXISTS show_ads BOOLEAN;

-- Update existing templates with some default limits
UPDATE public.business_type_templates 
SET max_transactions = 999999, max_products = 999999, max_outlets = 5, show_ads = false 
WHERE code = 'general';

UPDATE public.business_type_templates 
SET max_transactions = 500, max_products = 100, max_outlets = 1, show_ads = true 
WHERE code IN ('fnb', 'retail');
