-- Add business_type and enabled_features to businesses table
-- business_type: The template type chosen during onboarding (cafe, retail, etc)
-- enabled_features: List of active feature keys for this business (dynamic mapping)

ALTER TABLE public.businesses 
ADD COLUMN IF NOT EXISTS business_type text;

ALTER TABLE public.businesses 
ADD COLUMN IF NOT EXISTS enabled_features text[] DEFAULT '{}'::text[];

COMMENT ON COLUMN public.businesses.business_type IS 'The primary business category template (cafe, retail, laundry, showroom, kuliner).';
COMMENT ON COLUMN public.businesses.enabled_features IS 'List of dynamically enabled menu features for this specific business.';
