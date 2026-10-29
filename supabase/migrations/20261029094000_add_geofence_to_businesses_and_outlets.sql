-- Migration: Add geofence_radius and is_geofence_active to businesses and outlets
-- Purpose: Support online web store directory, delivery radius calculation, and cashier attendance geofencing.

ALTER TABLE public.businesses
ADD COLUMN IF NOT EXISTS geofence_radius INTEGER DEFAULT 5000,
ADD COLUMN IF NOT EXISTS is_geofence_active BOOLEAN DEFAULT true;

ALTER TABLE public.outlets
ADD COLUMN IF NOT EXISTS geofence_radius INTEGER DEFAULT 5000,
ADD COLUMN IF NOT EXISTS is_geofence_active BOOLEAN DEFAULT true;

COMMENT ON COLUMN public.businesses.geofence_radius IS 'Geofencing radius in meters for online store delivery & presence (e.g. 5000 = 5km)';
COMMENT ON COLUMN public.businesses.is_geofence_active IS 'Whether geofencing restriction is active for this business';

COMMENT ON COLUMN public.outlets.geofence_radius IS 'Geofencing radius in meters for outlet delivery & attendance';
COMMENT ON COLUMN public.outlets.is_geofence_active IS 'Whether geofencing restriction is active for this outlet';
