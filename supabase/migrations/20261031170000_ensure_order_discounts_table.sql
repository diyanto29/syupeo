-- Migration: 20261031170000_ensure_order_discounts_table.sql
-- Description: Memastikan tabel order_discounts dan foreign key constraint ke orders ada di database Supabase

CREATE TABLE IF NOT EXISTS public.order_discounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  discount_id UUID REFERENCES public.discounts(id) ON DELETE SET NULL,
  name TEXT NOT NULL DEFAULT 'Diskon',
  type TEXT NOT NULL DEFAULT 'percentage',
  percentage_value NUMERIC(5,2),
  amount_value NUMERIC(14,2),
  max_discount_amount NUMERIC(14,2),
  applied_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT order_discounts_name_not_blank CHECK (btrim(name) <> '')
);

CREATE INDEX IF NOT EXISTS order_discounts_order_idx ON public.order_discounts (order_id);

ALTER TABLE public.order_discounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "order_discounts_select" ON public.order_discounts;
CREATE POLICY "order_discounts_select" ON public.order_discounts
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "order_discounts_manage" ON public.order_discounts;
CREATE POLICY "order_discounts_manage" ON public.order_discounts
  FOR ALL USING (true);

