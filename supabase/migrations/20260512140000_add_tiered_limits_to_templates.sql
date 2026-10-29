-- Migration: Add limits_config to support separate limits for Free and Pro tiers
-- Date: 2026-05-12

-- Add limits_config to business_type_templates
ALTER TABLE public.business_type_templates 
ADD COLUMN IF NOT EXISTS limits_config JSONB NOT NULL DEFAULT '{"free": {}, "pro": {}}'::jsonb;

-- Add limits_config to businesses (for per-business overrides)
ALTER TABLE public.businesses 
ADD COLUMN IF NOT EXISTS limits_config JSONB NOT NULL DEFAULT '{"free": {}, "pro": {}}'::jsonb;

-- Initialize limits_config based on existing limit columns
UPDATE public.business_type_templates 
SET limits_config = jsonb_build_object(
    'free', jsonb_build_object(
        'max_transactions', max_transactions,
        'max_products', max_products,
        'max_outlets', max_outlets
    ),
    'pro', jsonb_build_object(
        'max_transactions', 999999, -- Default high for Pro
        'max_products', 999999,
        'max_outlets', 5
    )
);

-- Sync businesses as well
UPDATE public.businesses 
SET limits_config = jsonb_build_object(
    'free', jsonb_build_object(
        'max_transactions', COALESCE(max_transactions, 100),
        'max_products', COALESCE(max_products, 50),
        'max_outlets', COALESCE(max_outlets, 1)
    ),
    'pro', jsonb_build_object(
        'max_transactions', 999999,
        'max_products', 999999,
        'max_outlets', 5
    )
)
WHERE business_type IS NOT NULL;
