-- Migration: Add address and coordinates (latitude, longitude) to businesses and outlets
-- For digital web storefront, store locator, and delivery distance calculations.

ALTER TABLE public.businesses
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

ALTER TABLE public.outlets
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
