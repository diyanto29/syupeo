-- ====================================================================
-- Migration: Create Sales Returns & Item Returns Tracking System
-- Date: 2026-10-16
-- ====================================================================

-- 1. Tabel Header Retur Penjualan
CREATE TABLE IF NOT EXISTS public.sales_returns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    invoice_number VARCHAR(64) NOT NULL,
    return_number VARCHAR(64) UNIQUE NOT NULL,
    total_refund_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.0,
    refund_method VARCHAR(32) NOT NULL DEFAULT 'cash' CHECK (refund_method IN ('cash', 'transfer', 'store_credit', 'exchange')),
    reason VARCHAR(255) NOT NULL,
    notes TEXT,
    processed_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 2. Tabel Item yang Diretur
CREATE TABLE IF NOT EXISTS public.sales_return_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sales_return_id UUID NOT NULL REFERENCES public.sales_returns(id) ON DELETE CASCADE,
    order_item_id UUID REFERENCES public.order_items(id) ON DELETE SET NULL,
    menu_item_id UUID REFERENCES public.menu_items(id) ON DELETE SET NULL,
    item_name VARCHAR(255) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12, 2) NOT NULL DEFAULT 0.0,
    subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0.0,
    condition VARCHAR(32) NOT NULL DEFAULT 'restockable' CHECK (condition IN ('restockable', 'damaged_waste')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- Indexing
CREATE INDEX IF NOT EXISTS idx_sales_returns_order ON public.sales_returns(order_id);
CREATE INDEX IF NOT EXISTS idx_sales_returns_business ON public.sales_returns(business_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sales_return_items_ret ON public.sales_return_items(sales_return_id);

-- Enable RLS
ALTER TABLE public.sales_returns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_return_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated read sales_returns" ON public.sales_returns
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow authenticated insert sales_returns" ON public.sales_returns
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow authenticated read sales_return_items" ON public.sales_return_items
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow authenticated insert sales_return_items" ON public.sales_return_items
    FOR INSERT TO authenticated WITH CHECK (true);
