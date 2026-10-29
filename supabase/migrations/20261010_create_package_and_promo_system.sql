-- Migration: 20261010_create_package_and_promo_system.sql
-- Description: Adds bundling/package menu support and promotions system (BXGY & Tebus Murah / PWP)

-- 1. Alter menu_items to support packages
ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS is_package BOOLEAN NOT NULL DEFAULT false;

-- 2. Create menu_package_items table
CREATE TABLE IF NOT EXISTS menu_package_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    component_menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    quantity INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_menu_package_items_package_id ON menu_package_items(package_menu_item_id);
CREATE INDEX IF NOT EXISTS idx_menu_package_items_component_id ON menu_package_items(component_menu_item_id);

-- Enable RLS for menu_package_items
ALTER TABLE menu_package_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "menu_package_items_select_policy" ON menu_package_items;
DROP POLICY IF EXISTS "menu_package_items_manage_policy" ON menu_package_items;
DROP POLICY IF EXISTS "Users can view package items of their businesses" ON menu_package_items;
DROP POLICY IF EXISTS "Users can insert package items of their businesses" ON menu_package_items;
DROP POLICY IF EXISTS "Users can update package items of their businesses" ON menu_package_items;
DROP POLICY IF EXISTS "Users can delete package items of their businesses" ON menu_package_items;

CREATE POLICY "menu_package_items_select_policy" ON menu_package_items
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM menu_items m
            WHERE m.id = menu_package_items.package_menu_item_id
              AND (
                  public.is_business_owner(m.business_id)
                  OR public.is_business_member(m.business_id, auth.uid())
                  OR EXISTS (
                      SELECT 1 FROM public.outlet_members om
                      JOIN public.outlets o ON o.id = om.outlet_id
                      WHERE o.business_id = m.business_id
                        AND om.user_id = auth.uid()
                        AND om.status = 'active'
                  )
              )
        )
    );

CREATE POLICY "menu_package_items_manage_policy" ON menu_package_items
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM menu_items m
            WHERE m.id = menu_package_items.package_menu_item_id
              AND (
                  public.is_business_owner(m.business_id)
                  OR EXISTS (
                      SELECT 1 FROM public.business_members bm
                      WHERE bm.business_id = m.business_id
                        AND bm.user_id = auth.uid()
                        AND bm.status = 'active'
                        AND bm.role IN ('owner', 'admin')
                  )
              )
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM menu_items m
            WHERE m.id = package_menu_item_id
              AND (
                  public.is_business_owner(m.business_id)
                  OR EXISTS (
                      SELECT 1 FROM public.business_members bm
                      WHERE bm.business_id = m.business_id
                        AND bm.user_id = auth.uid()
                        AND bm.status = 'active'
                        AND bm.role IN ('owner', 'admin')
                  )
              )
        )
    );

-- 3. Create buy_x_get_y_promos table (Beli X Gratis Y / BOGO)
CREATE TABLE IF NOT EXISTS buy_x_get_y_promos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    mode TEXT NOT NULL DEFAULT 'same_product' CHECK (mode IN ('same_product', 'cross_product')),
    trigger_menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    min_buy_qty INT NOT NULL DEFAULT 1 CHECK (min_buy_qty > 0),
    reward_menu_item_id UUID REFERENCES menu_items(id) ON DELETE CASCADE,
    reward_qty INT NOT NULL DEFAULT 1 CHECK (reward_qty > 0),
    is_multiple_allowed BOOLEAN NOT NULL DEFAULT true,
    max_reward_per_transaction INT NOT NULL DEFAULT 1 CHECK (max_reward_per_transaction > 0),
    start_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    end_date TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '30 days'),
    active_days INT[] DEFAULT '{1,2,3,4,5,6,7}',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_buy_x_get_y_promos_business ON buy_x_get_y_promos(business_id);
CREATE INDEX IF NOT EXISTS idx_buy_x_get_y_promos_trigger ON buy_x_get_y_promos(trigger_menu_item_id);

ALTER TABLE buy_x_get_y_promos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "buy_x_get_y_promos_select_policy" ON buy_x_get_y_promos;
DROP POLICY IF EXISTS "buy_x_get_y_promos_manage_policy" ON buy_x_get_y_promos;
DROP POLICY IF EXISTS "Users can view buy_x_get_y_promos of their businesses" ON buy_x_get_y_promos;
DROP POLICY IF EXISTS "Users can insert buy_x_get_y_promos of their businesses" ON buy_x_get_y_promos;
DROP POLICY IF EXISTS "Users can update buy_x_get_y_promos of their businesses" ON buy_x_get_y_promos;
DROP POLICY IF EXISTS "Users can delete buy_x_get_y_promos of their businesses" ON buy_x_get_y_promos;

CREATE POLICY "buy_x_get_y_promos_select_policy" ON buy_x_get_y_promos
    FOR SELECT TO authenticated
    USING (
        public.is_business_owner(business_id) OR
        public.is_business_member(business_id, auth.uid()) OR
        EXISTS (
            SELECT 1 FROM public.outlet_members om
            JOIN public.outlets o ON o.id = om.outlet_id
            WHERE o.business_id = buy_x_get_y_promos.business_id
              AND om.user_id = auth.uid()
              AND om.status = 'active'
        )
    );

CREATE POLICY "buy_x_get_y_promos_manage_policy" ON buy_x_get_y_promos
    FOR ALL TO authenticated
    USING (
        public.is_business_owner(business_id) OR
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = buy_x_get_y_promos.business_id
              AND bm.user_id = auth.uid()
              AND bm.status = 'active'
              AND bm.role IN ('owner', 'admin')
        )
    )
    WITH CHECK (
        public.is_business_owner(business_id) OR
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = business_id
              AND bm.user_id = auth.uid()
              AND bm.status = 'active'
              AND bm.role IN ('owner', 'admin')
        )
    );

-- 4. Create tebus_murah_promos table (Purchase With Purchase / PWP)
CREATE TABLE IF NOT EXISTS tebus_murah_promos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    mode TEXT NOT NULL DEFAULT 'min_spend' CHECK (mode IN ('min_spend', 'product_combo')),
    min_spend_amount NUMERIC(12, 2) DEFAULT 0,
    trigger_menu_item_id UUID REFERENCES menu_items(id) ON DELETE CASCADE,
    reward_menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    special_price NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (special_price >= 0),
    max_qty_per_transaction INT NOT NULL DEFAULT 1 CHECK (max_qty_per_transaction > 0),
    start_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    end_date TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '30 days'),
    active_days INT[] DEFAULT '{1,2,3,4,5,6,7}',
    active_time_start TEXT,
    active_time_end TEXT,
    quota_limit INT,
    current_usage_count INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tebus_murah_promos_business ON tebus_murah_promos(business_id);
CREATE INDEX IF NOT EXISTS idx_tebus_murah_promos_reward ON tebus_murah_promos(reward_menu_item_id);

ALTER TABLE tebus_murah_promos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tebus_murah_promos_select_policy" ON tebus_murah_promos;
DROP POLICY IF EXISTS "tebus_murah_promos_manage_policy" ON tebus_murah_promos;
DROP POLICY IF EXISTS "Users can view tebus_murah_promos of their businesses" ON tebus_murah_promos;
DROP POLICY IF EXISTS "Users can insert tebus_murah_promos of their businesses" ON tebus_murah_promos;
DROP POLICY IF EXISTS "Users can update tebus_murah_promos of their businesses" ON tebus_murah_promos;
DROP POLICY IF EXISTS "Users can delete tebus_murah_promos of their businesses" ON tebus_murah_promos;

CREATE POLICY "tebus_murah_promos_select_policy" ON tebus_murah_promos
    FOR SELECT TO authenticated
    USING (
        public.is_business_owner(business_id) OR
        public.is_business_member(business_id, auth.uid()) OR
        EXISTS (
            SELECT 1 FROM public.outlet_members om
            JOIN public.outlets o ON o.id = om.outlet_id
            WHERE o.business_id = tebus_murah_promos.business_id
              AND om.user_id = auth.uid()
              AND om.status = 'active'
        )
    );

CREATE POLICY "tebus_murah_promos_manage_policy" ON tebus_murah_promos
    FOR ALL TO authenticated
    USING (
        public.is_business_owner(business_id) OR
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = tebus_murah_promos.business_id
              AND bm.user_id = auth.uid()
              AND bm.status = 'active'
              AND bm.role IN ('owner', 'admin')
        )
    )
    WITH CHECK (
        public.is_business_owner(business_id) OR
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = business_id
              AND bm.user_id = auth.uid()
              AND bm.status = 'active'
              AND bm.role IN ('owner', 'admin')
        )
    );

-- 5. Updated_at Triggers
DROP TRIGGER IF EXISTS trg_buy_x_get_y_promos_updated_at ON buy_x_get_y_promos;
CREATE TRIGGER trg_buy_x_get_y_promos_updated_at
    BEFORE UPDATE ON buy_x_get_y_promos
    FOR EACH ROW
    EXECUTE PROCEDURE handle_updated_at();

DROP TRIGGER IF EXISTS trg_tebus_murah_promos_updated_at ON tebus_murah_promos;
CREATE TRIGGER trg_tebus_murah_promos_updated_at
    BEFORE UPDATE ON tebus_murah_promos
    FOR EACH ROW
    EXECUTE PROCEDURE handle_updated_at();
