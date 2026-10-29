-- Migration: Add features_config to support Free/Pro gating per template
-- Date: 2026-05-12

-- Add features_config to business_type_templates
ALTER TABLE public.business_type_templates 
ADD COLUMN IF NOT EXISTS features_config JSONB NOT NULL DEFAULT '{}'::jsonb;

-- Add features_config to businesses (for per-business overrides)
ALTER TABLE public.businesses 
ADD COLUMN IF NOT EXISTS features_config JSONB NOT NULL DEFAULT '{}'::jsonb;

-- Initialize features_config based on existing default_enabled_features
-- We assume existing enabled features are 'free' by default for now
UPDATE public.business_type_templates 
SET features_config = (
    SELECT jsonb_object_agg(feat, 'free')
    FROM jsonb_array_elements_text(default_enabled_features) AS feat
)
WHERE default_enabled_features != '[]'::jsonb;

-- Update specific templates for testing Pro features
UPDATE public.business_type_templates 
SET features_config = features_config || '{"inventory": "pro", "qr_order": "pro", "reports": "pro"}'::jsonb
WHERE code IN ('fnb', 'retail', 'general');
 