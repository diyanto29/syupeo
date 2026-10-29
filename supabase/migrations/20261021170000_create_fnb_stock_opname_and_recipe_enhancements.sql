-- ============================================================================
-- F&B INVENTORY & STOCK OPNAME SYSTEM
-- 1. Sesi Stock Opname Masal (stock_opname_sessions & stock_opname_items)
-- 2. Pencatatan Bahan Terbuang / Rusak (inventory_waste_logs)
-- 3. Resep Modular Tingkat Varian (menu_item_recipes variant support)
-- ============================================================================

-- 1. Sesi Stock Opname (stock_opname_sessions)
CREATE TABLE IF NOT EXISTS public.stock_opname_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
    session_number VARCHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'draft',               -- 'draft', 'in_progress', 'completed', 'cancelled'
    opname_type VARCHAR(32) NOT NULL DEFAULT 'daily_closing',   -- 'daily_closing', 'weekly', 'full_monthly'
    notes TEXT,
    total_system_value NUMERIC(15, 2) DEFAULT 0,
    total_physical_value NUMERIC(15, 2) DEFAULT 0,
    total_discrepancy_value NUMERIC(15, 2) DEFAULT 0,
    started_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
    completed_at TIMESTAMPTZ,
    conducted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    approved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_opname_sessions_outlet ON public.stock_opname_sessions(outlet_id, status);
CREATE INDEX IF NOT EXISTS idx_opname_sessions_business ON public.stock_opname_sessions(business_id);

-- 2. Rincian Item Opname (stock_opname_items)
CREATE TABLE IF NOT EXISTS public.stock_opname_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.stock_opname_sessions(id) ON DELETE CASCADE,
    ingredient_id UUID REFERENCES public.inventory_ingredients(id) ON DELETE CASCADE,
    menu_item_id UUID REFERENCES public.menu_items(id) ON DELETE SET NULL,
    item_name VARCHAR(255) NOT NULL,
    storage_location VARCHAR(64) DEFAULT 'General',
    unit VARCHAR(32) NOT NULL DEFAULT 'pcs',
    system_stock NUMERIC(12, 4) NOT NULL DEFAULT 0,
    physical_stock NUMERIC(12, 4) NOT NULL DEFAULT 0,
    discrepancy_quantity NUMERIC(12, 4) GENERATED ALWAYS AS (physical_stock - system_stock) STORED,
    unit_cost NUMERIC(15, 2) NOT NULL DEFAULT 0,
    discrepancy_value NUMERIC(15, 2) GENERATED ALWAYS AS ((physical_stock - system_stock) * unit_cost) STORED,
    discrepancy_reason VARCHAR(64),                           -- 'spoilage', 'damaged', 'unrecorded_use', 'theft', 'count_error', 'none'
    notes TEXT,
    counted_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_opname_items_session ON public.stock_opname_items(session_id);
CREATE INDEX IF NOT EXISTS idx_opname_items_ingredient ON public.stock_opname_items(ingredient_id);

-- 3. Pencatatan Bahan Terbuang / Rusak / Basi (inventory_waste_logs)
CREATE TABLE IF NOT EXISTS public.inventory_waste_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
    ingredient_id UUID NOT NULL REFERENCES public.inventory_ingredients(id) ON DELETE CASCADE,
    quantity NUMERIC(12, 4) NOT NULL,
    unit VARCHAR(32) NOT NULL,
    unit_cost NUMERIC(15, 2) NOT NULL DEFAULT 0,
    total_loss_cost NUMERIC(15, 2) GENERATED ALWAYS AS (quantity * unit_cost) STORED,
    waste_reason VARCHAR(64) NOT NULL,                         -- 'expired', 'spilled', 'wrong_preparation', 'staff_meal', 'complimentary', 'damaged'
    notes TEXT,
    reported_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_waste_logs_business ON public.inventory_waste_logs(business_id);
CREATE INDEX IF NOT EXISTS idx_waste_logs_outlet ON public.inventory_waste_logs(outlet_id);
CREATE INDEX IF NOT EXISTS idx_waste_logs_ingredient ON public.inventory_waste_logs(ingredient_id);

-- 4. Modifikasi Resep Menu untuk Dukungan Varian & Topping
-- Drop existing unique constraint (menu_item_id, ingredient_id) jika ada agar bisa beda varian
ALTER TABLE public.menu_item_recipes DROP CONSTRAINT IF EXISTS menu_item_recipe_unique;

ALTER TABLE public.menu_item_recipes 
ADD COLUMN IF NOT EXISTS variant_id UUID REFERENCES public.menu_item_variants(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS modifier_option_id UUID,
ADD COLUMN IF NOT EXISTS notes VARCHAR(128);

-- Buat unique constraint baru yang menyertakan variant_id (NULLS NOT DISTINCT di Postgres 15+ atau unique index dengan COALESCE)
CREATE UNIQUE INDEX IF NOT EXISTS idx_menu_item_recipes_variant_unique 
ON public.menu_item_recipes(menu_item_id, COALESCE(variant_id, '00000000-0000-0000-0000-000000000000'::uuid), ingredient_id);

-- 5. Enable RLS
ALTER TABLE public.stock_opname_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_opname_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_waste_logs ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies
DROP POLICY IF EXISTS "opname_sessions_business_access" ON public.stock_opname_sessions;
CREATE POLICY "opname_sessions_business_access" ON public.stock_opname_sessions
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = stock_opname_sessions.business_id
              AND bm.user_id = auth.uid()
              AND bm.status = 'active'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = stock_opname_sessions.business_id
              AND bm.user_id = auth.uid()
              AND bm.status = 'active'
        )
    );

DROP POLICY IF EXISTS "opname_items_session_access" ON public.stock_opname_items;
CREATE POLICY "opname_items_session_access" ON public.stock_opname_items
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.stock_opname_sessions s
            JOIN public.business_members bm ON bm.business_id = s.business_id
            WHERE s.id = stock_opname_items.session_id
              AND bm.user_id = auth.uid()
              AND bm.status = 'active'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.stock_opname_sessions s
            JOIN public.business_members bm ON bm.business_id = s.business_id
            WHERE s.id = stock_opname_items.session_id
              AND bm.user_id = auth.uid()
              AND bm.status = 'active'
        )
    );

DROP POLICY IF EXISTS "waste_logs_business_access" ON public.inventory_waste_logs;
CREATE POLICY "waste_logs_business_access" ON public.inventory_waste_logs
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = inventory_waste_logs.business_id
              AND bm.user_id = auth.uid()
              AND bm.status = 'active'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = inventory_waste_logs.business_id
              AND bm.user_id = auth.uid()
              AND bm.status = 'active'
        )
    );
