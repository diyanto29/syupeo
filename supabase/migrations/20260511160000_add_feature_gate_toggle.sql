-- Migration: Add feature gate toggle to businesses
-- Date: 2026-05-11

ALTER TABLE public.businesses 
ADD COLUMN IF NOT EXISTS is_feature_gate_enabled BOOLEAN NOT NULL DEFAULT true;

COMMENT ON COLUMN public.businesses.is_feature_gate_enabled IS 'Toggle to enable or disable plan-based feature gating. If false, all features are unlocked.';
