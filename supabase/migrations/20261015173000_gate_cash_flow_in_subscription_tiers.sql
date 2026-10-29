-- ============================================================================
-- Migration: Gate Cash Flow (Arus Kas & Shift Kasir) in Subscription Tiers
-- Description: Integrates cash_flow into Free vs Pro tier system (Pro feature)
-- ============================================================================

-- 1. Update subscription_plans table
-- Free Plan: cash_flow is disabled (false)
UPDATE public.subscription_plans
SET features = jsonb_set(COALESCE(features, '{}'::jsonb), '{cash_flow}', 'false'::jsonb, true)
WHERE code = 'free';

-- Pro & Enterprise Plans: cash_flow is enabled (true)
UPDATE public.subscription_plans
SET features = jsonb_set(COALESCE(features, '{}'::jsonb), '{cash_flow}', 'true'::jsonb, true)
WHERE code IN ('pro', 'enterprise');

-- 2. Update business_type_templates table
-- Set cash_flow as a 'pro' feature across all templates (F&B, Retail, General, Service)
UPDATE public.business_type_templates
SET features_config = COALESCE(features_config, '{}'::jsonb) || '{"cash_flow": "pro"}'::jsonb;

-- 3. Sync existing businesses whose features_config does not yet specify cash_flow
UPDATE public.businesses
SET features_config = COALESCE(features_config, '{}'::jsonb) || '{"cash_flow": "pro"}'::jsonb
WHERE NOT (COALESCE(features_config, '{}'::jsonb) ? 'cash_flow');
