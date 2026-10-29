-- Migration to add tiered pricing support to menu items
CREATE TABLE IF NOT EXISTS menu_item_tiered_prices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    min_quantity INTEGER NOT NULL CHECK (min_quantity > 0),
    price NUMERIC NOT NULL DEFAULT 0,
    business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(menu_item_id, min_quantity)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS menu_item_tiered_prices_menu_item_id_idx ON menu_item_tiered_prices(menu_item_id);
CREATE INDEX IF NOT EXISTS menu_item_tiered_prices_business_id_idx ON menu_item_tiered_prices(business_id);

-- Add comment
COMMENT ON TABLE menu_item_tiered_prices IS 'Table to store tiered pricing for products (e.g., bulk discounts based on quantity).';

-- Trigger for updated_at
CREATE TRIGGER update_menu_item_tiered_prices_updated_at
    BEFORE UPDATE ON menu_item_tiered_prices
    FOR EACH ROW
    EXECUTE PROCEDURE handle_updated_at();

-- RLS Policies
ALTER TABLE menu_item_tiered_prices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "menu_item_tiered_prices_manage_policy" ON menu_item_tiered_prices
    FOR ALL
    TO authenticated
    USING (
        public.is_business_owner(business_id) OR
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = menu_item_tiered_prices.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role IN ('owner', 'admin')
        )
    )
    WITH CHECK (
        public.is_business_owner(business_id) OR
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = menu_item_tiered_prices.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role IN ('owner', 'admin')
        )
    );

CREATE POLICY "menu_item_tiered_prices_select_policy" ON menu_item_tiered_prices
    FOR SELECT
    TO authenticated
    USING (
        public.is_business_owner(business_id) OR
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = menu_item_tiered_prices.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
        ) OR
        EXISTS (
            SELECT 1 FROM public.outlet_members om
            JOIN public.outlets o ON o.id = om.outlet_id
            WHERE o.business_id = menu_item_tiered_prices.business_id
              AND om.user_id = auth.uid()
              AND om.status = 'active'
        )
    );
