-- Migration to add variants and barcode support to menu items
-- 1. Add barcode/sku to menu_items (optional, for the item itself)
ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS sku TEXT;
ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS barcode TEXT;

-- 2. Create menu_item_variants table
CREATE TABLE IF NOT EXISTS menu_item_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    name TEXT NOT NULL, -- e.g., 'Small', 'Large', 'Pack of 10'
    price NUMERIC NOT NULL DEFAULT 0,
    sku TEXT,
    barcode TEXT,
    stock_available BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Add business_id to variants for RBAC if needed (though cascading from menu_items might be enough)
-- But for better RLS performance, adding business_id here is good practice.
ALTER TABLE menu_item_variants ADD COLUMN IF NOT EXISTS business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE;

-- Create indexes
CREATE INDEX IF NOT EXISTS menu_item_variants_menu_item_id_idx ON menu_item_variants(menu_item_id);
CREATE INDEX IF NOT EXISTS menu_item_variants_business_id_idx ON menu_item_variants(business_id);
CREATE INDEX IF NOT EXISTS menu_item_variants_barcode_idx ON menu_item_variants(barcode);

-- Add comment
COMMENT ON TABLE menu_item_variants IS 'Table to store product variants (sizes, versions) with distinct pricing and barcodes.';

-- Trigger for updated_at
CREATE TRIGGER update_menu_item_variants_updated_at
    BEFORE UPDATE ON menu_item_variants
    FOR EACH ROW
    EXECUTE PROCEDURE handle_updated_at();

-- RLS Policies
ALTER TABLE menu_item_variants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "menu_item_variants_manage_policy" ON menu_item_variants
    FOR ALL
    TO authenticated
    USING (
        public.is_business_owner(business_id) OR
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = menu_item_variants.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role IN ('owner', 'admin')
        )
    )
    WITH CHECK (
        public.is_business_owner(business_id) OR
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = menu_item_variants.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role IN ('owner', 'admin')
        )
    );

CREATE POLICY "menu_item_variants_select_policy" ON menu_item_variants
    FOR SELECT
    TO authenticated
    USING (
        public.is_business_owner(business_id) OR
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = menu_item_variants.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
        ) OR
        EXISTS (
            SELECT 1 FROM public.outlet_members om
            JOIN public.outlets o ON o.id = om.outlet_id
            WHERE o.business_id = menu_item_variants.business_id
              AND om.user_id = auth.uid()
              AND om.status = 'active'
        )
    );
