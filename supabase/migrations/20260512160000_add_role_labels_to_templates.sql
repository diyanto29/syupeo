-- Add role_labels column to business_type_templates table
ALTER TABLE business_type_templates 
ADD COLUMN IF NOT EXISTS role_labels JSONB DEFAULT '{}'::jsonb;

-- Add role_labels column to businesses table
ALTER TABLE businesses 
ADD COLUMN IF NOT EXISTS role_labels JSONB DEFAULT '{}'::jsonb;
