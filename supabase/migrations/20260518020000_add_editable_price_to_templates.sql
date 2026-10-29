-- Migration: Add editable_price feature flag to templates and active businesses
-- Date: 2026-05-18

-- 1. Update business_type_templates features_config
-- Let's make editable_price 'free' for showroom motor, and 'pro' for others
UPDATE public.business_type_templates
SET features_config = features_config || '{"editable_price": "free"}'::jsonb
WHERE code = 'showroom';

UPDATE public.business_type_templates
SET features_config = features_config || '{"editable_price": "pro"}'::jsonb
WHERE code != 'showroom';

-- 2. Update existing businesses features_config to include editable_price if not already present
-- We match the templates to make sure they get the correct default based on their business_type
UPDATE public.businesses b
SET features_config = b.features_config || jsonb_build_object('editable_price', COALESCE(t.features_config->>'editable_price', 'pro'))
FROM public.business_type_templates t
WHERE b.business_type = t.code
  AND (b.features_config->>'editable_price') IS NULL;
