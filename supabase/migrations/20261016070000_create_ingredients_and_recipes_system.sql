-- ============================================================================
-- F&B INVENTORY: RAW MATERIALS (BAHAN BAKU), RECIPES (BOM), & AUTO-DEDUCTION
-- ============================================================================

-- 1. Inventory Ingredients (Bahan Baku)
CREATE TABLE IF NOT EXISTS public.inventory_ingredients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
    sku VARCHAR(64),
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    base_unit VARCHAR(32) NOT NULL DEFAULT 'gram',             -- gram, ml, pcs, lembar
    purchase_unit VARCHAR(32) DEFAULT 'kg',                    -- kg, liter, dus, pack
    conversion_ratio NUMERIC(12, 4) DEFAULT 1000.0,            -- 1 purchase_unit = conversion_ratio * base_unit
    current_stock NUMERIC(12, 4) NOT NULL DEFAULT 0.0,
    min_stock_alert NUMERIC(12, 4) NOT NULL DEFAULT 0.0,
    cost_per_base_unit NUMERIC(12, 2) NOT NULL DEFAULT 0.0,
    storage_type VARCHAR(32) DEFAULT 'dry',                    -- dry, chilled, frozen
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_ingredients_business ON public.inventory_ingredients(business_id);
CREATE INDEX IF NOT EXISTS idx_ingredients_category ON public.inventory_ingredients(category);

-- 2. Menu Item Recipes (Resep / Bill of Materials)
CREATE TABLE IF NOT EXISTS public.menu_item_recipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES public.menu_items(id) ON DELETE CASCADE,
    ingredient_id UUID NOT NULL REFERENCES public.inventory_ingredients(id) ON DELETE CASCADE,
    quantity_required NUMERIC(12, 4) NOT NULL,                 -- Takaran per porsi (misal 18.0 gram)
    unit VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    CONSTRAINT menu_item_recipe_unique UNIQUE(menu_item_id, ingredient_id)
);

CREATE INDEX IF NOT EXISTS idx_recipes_menu_item ON public.menu_item_recipes(menu_item_id);
CREATE INDEX IF NOT EXISTS idx_recipes_ingredient ON public.menu_item_recipes(ingredient_id);

-- 3. Ingredient Movements (Buku Besar Mutasi Bahan Baku)
CREATE TABLE IF NOT EXISTS public.ingredient_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
    ingredient_id UUID NOT NULL REFERENCES public.inventory_ingredients(id) ON DELETE CASCADE,
    movement_type VARCHAR(48) NOT NULL,                        -- opening_balance, in_purchase, out_recipe_deduction, adjustment, waste, sales_return
    quantity_delta NUMERIC(12, 4) NOT NULL,                    -- Positif untuk masuk, negatif untuk keluar
    balance_after NUMERIC(12, 4) NOT NULL,
    note TEXT,
    reference_id TEXT,
    performed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_ingredient_movements_ingredient ON public.ingredient_movements(ingredient_id);
CREATE INDEX IF NOT EXISTS idx_ingredient_movements_created ON public.ingredient_movements(created_at DESC);

-- 4. Enable RLS
ALTER TABLE public.inventory_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_item_recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ingredient_movements ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies
DROP POLICY IF EXISTS "ingredients_business_access" ON public.inventory_ingredients;
CREATE POLICY "ingredients_business_access" ON public.inventory_ingredients
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = inventory_ingredients.business_id
              AND bm.user_id = auth.uid()
              AND bm.status = 'active'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = inventory_ingredients.business_id
              AND bm.user_id = auth.uid()
              AND bm.status = 'active'
        )
    );

DROP POLICY IF EXISTS "recipes_business_access" ON public.menu_item_recipes;
CREATE POLICY "recipes_business_access" ON public.menu_item_recipes
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = menu_item_recipes.business_id
              AND bm.user_id = auth.uid()
              AND bm.status = 'active'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = menu_item_recipes.business_id
              AND bm.user_id = auth.uid()
              AND bm.status = 'active'
        )
    );

DROP POLICY IF EXISTS "ingredient_movements_business_access" ON public.ingredient_movements;
CREATE POLICY "ingredient_movements_business_access" ON public.ingredient_movements
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = ingredient_movements.business_id
              AND bm.user_id = auth.uid()
              AND bm.status = 'active'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = ingredient_movements.business_id
              AND bm.user_id = auth.uid()
              AND bm.status = 'active'
        )
    );

-- 6. Trigger to automatically re-calculate recipe_cost on menu_items
CREATE OR REPLACE FUNCTION public.recalculate_menu_item_recipe_cost()
RETURNS TRIGGER AS $$
DECLARE
    target_menu_item_id UUID;
    total_cost NUMERIC(12, 2);
BEGIN
    target_menu_item_id := COALESCE(NEW.menu_item_id, OLD.menu_item_id);

    SELECT COALESCE(SUM(mir.quantity_required * ing.cost_per_base_unit), 0.0)
    INTO total_cost
    FROM public.menu_item_recipes mir
    JOIN public.inventory_ingredients ing ON ing.id = mir.ingredient_id
    WHERE mir.menu_item_id = target_menu_item_id;

    UPDATE public.menu_items
    SET recipe_cost = total_cost
    WHERE id = target_menu_item_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_recalculate_recipe_cost ON public.menu_item_recipes;
CREATE TRIGGER tr_recalculate_recipe_cost
    AFTER INSERT OR UPDATE OR DELETE ON public.menu_item_recipes
    FOR EACH ROW
    EXECUTE FUNCTION public.recalculate_menu_item_recipe_cost();

-- Grant permissions to authenticated
GRANT ALL ON public.inventory_ingredients TO authenticated;
GRANT ALL ON public.menu_item_recipes TO authenticated;
GRANT ALL ON public.ingredient_movements TO authenticated;
