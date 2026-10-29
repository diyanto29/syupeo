-- Enable search extension if not exists
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create a master catalog table for global product reference
CREATE TABLE IF NOT EXISTS public.master_catalog (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    barcode TEXT UNIQUE,
    name TEXT NOT NULL,
    category TEXT,
    brand TEXT,
    base_price NUMERIC DEFAULT 0, -- Modal / HPP reference
    selling_price NUMERIC DEFAULT 0, -- Harga jual reference
    unit TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Index for fast barcode lookup
CREATE INDEX IF NOT EXISTS master_catalog_barcode_idx ON master_catalog(barcode);
CREATE INDEX IF NOT EXISTS master_catalog_name_idx ON master_catalog USING gin(name gin_trgm_ops); -- Requires pg_trgm extension

-- RLS: Read-only for all authenticated users
ALTER TABLE master_catalog ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow read access for all users" ON master_catalog
    FOR SELECT
    TO authenticated
    USING (true);
