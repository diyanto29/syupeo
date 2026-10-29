-- ============================================================================
-- Migration: Add Composite & High-Traffic Indexes for Speed & Scalability
-- Description: Accelerates dashboard, reporting, order lookups, and product catalog
-- ============================================================================

-- 1. Orders: Faster period-based queries, status filtering, and multi-outlet summaries
CREATE INDEX IF NOT EXISTS idx_orders_outlet_created_status 
  ON public.orders (outlet_id, created_at DESC, status);

CREATE INDEX IF NOT EXISTS idx_orders_business_created 
  ON public.orders (business_id, created_at DESC);

-- 2. Order Items: Faster joins with menu_items for profit/recipe_cost and top-selling calculations
CREATE INDEX IF NOT EXISTS idx_order_items_menu_item_id 
  ON public.order_items (menu_item_id);

-- 3. Cash Flow Entries: Faster expense & cash-in aggregations by outlet and period
CREATE INDEX IF NOT EXISTS idx_cash_flow_outlet_type_created 
  ON public.cash_flow_entries (outlet_id, type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_cash_flow_business_created 
  ON public.cash_flow_entries (business_id, created_at DESC);

-- 4. Menu Items: Faster category filtering, sorting by name or last updated in POS grid
CREATE INDEX IF NOT EXISTS idx_menu_items_business_category 
  ON public.menu_items (business_id, category_id);

CREATE INDEX IF NOT EXISTS idx_menu_items_business_updated 
  ON public.menu_items (business_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_menu_items_business_name 
  ON public.menu_items (business_id, name);
