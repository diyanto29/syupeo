-- Migration: Sync Business Feature Configs from Templates for empty/null fields
-- Date: 2026-05-18

UPDATE public.businesses b
SET 
  features_config = t.features_config,
  limits_config = t.limits_config,
  role_labels = t.role_labels,
  max_transactions = COALESCE(b.max_transactions, t.max_transactions),
  max_products = COALESCE(b.max_products, t.max_products),
  max_outlets = COALESCE(b.max_outlets, t.max_outlets)
FROM public.business_type_templates t
WHERE b.business_type = t.code 
  AND (b.features_config = '{}'::jsonb OR b.features_config IS NULL);
