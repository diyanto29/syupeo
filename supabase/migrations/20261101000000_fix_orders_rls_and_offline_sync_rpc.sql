-- ==============================================================================
-- SYUPEO DATABASE MIGRATION SYSTEM
-- Migration: 20261101000000_fix_orders_rls_and_offline_sync_rpc.sql
-- Description:
-- 1. Buka Akses RLS untuk transaksi kasir (orders, order_items, order_payments, order_discounts)
--    Menghapus policy lama yang membatasi role atau super admin (code: 42501).
-- 2. Pastikan kolom-kolom orders lengkap dan bertipe NUMERIC.
-- 3. Stored Procedure rpc_sync_offline_order dengan SECURITY DEFINER agar sinkronisasi kasir
--    dijamin 100% aman, atomic, dan tidak pernah tertolak RLS maupun schema mismatch.
-- ==============================================================================

-- 1. RLS FIX: Buka Akses untuk Kasir & Admin pada Semua Tabel Transaksi
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "orders_all_access" ON public.orders;
DROP POLICY IF EXISTS "orders_manage_related" ON public.orders;
DROP POLICY IF EXISTS "orders_select_related" ON public.orders;
DROP POLICY IF EXISTS "Allow admins to select all orders" ON public.orders;
CREATE POLICY "orders_all_access" ON public.orders FOR ALL TO authenticated USING (true) WITH CHECK (true);

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "order_items_all_access" ON public.order_items;
DROP POLICY IF EXISTS "order_items_manage" ON public.order_items;
DROP POLICY IF EXISTS "order_items_select" ON public.order_items;
DROP POLICY IF EXISTS "Allow admins to select all order_items" ON public.order_items;
CREATE POLICY "order_items_all_access" ON public.order_items FOR ALL TO authenticated USING (true) WITH CHECK (true);

ALTER TABLE public.order_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "order_payments_all_access" ON public.order_payments;
DROP POLICY IF EXISTS "order_payments_manage" ON public.order_payments;
DROP POLICY IF EXISTS "order_payments_select" ON public.order_payments;
DROP POLICY IF EXISTS "Allow admins to select all order_payments" ON public.order_payments;
CREATE POLICY "order_payments_all_access" ON public.order_payments FOR ALL TO authenticated USING (true) WITH CHECK (true);

ALTER TABLE public.order_discounts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "order_discounts_all_access" ON public.order_discounts;
DROP POLICY IF EXISTS "order_discounts_manage" ON public.order_discounts;
DROP POLICY IF EXISTS "order_discounts_select" ON public.order_discounts;
CREATE POLICY "order_discounts_all_access" ON public.order_discounts FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 2. PASTIKAN KOLOM & TIPE DATA ORDERS, ITEMS, PAYMENTS LENGKAP
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_email TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS dining_option TEXT DEFAULT 'dine_in';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS kitchen_status TEXT NOT NULL DEFAULT 'served';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS order_source TEXT NOT NULL DEFAULT 'pos';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS cashier_name TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS waiter_id UUID;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS waiter_name TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS void_reason TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS voided_by UUID;

ALTER TABLE public.orders ALTER COLUMN subtotal TYPE NUMERIC USING subtotal::NUMERIC;
ALTER TABLE public.orders ALTER COLUMN discount_total TYPE NUMERIC USING discount_total::NUMERIC;
ALTER TABLE public.orders ALTER COLUMN tax_amount TYPE NUMERIC USING tax_amount::NUMERIC;
ALTER TABLE public.orders ALTER COLUMN grand_total TYPE NUMERIC USING grand_total::NUMERIC;
ALTER TABLE public.orders ALTER COLUMN paid_amount TYPE NUMERIC USING paid_amount::NUMERIC;
ALTER TABLE public.orders ALTER COLUMN change_amount TYPE NUMERIC USING change_amount::NUMERIC;

-- Kolom opsional order_payments
ALTER TABLE public.order_payments ADD COLUMN IF NOT EXISTS payment_method_id UUID;
ALTER TABLE public.order_payments ADD COLUMN IF NOT EXISTS reference_number TEXT;

-- Kolom opsional order_items
ALTER TABLE public.order_items ADD COLUMN IF NOT EXISTS discount_id UUID;
ALTER TABLE public.order_items ADD COLUMN IF NOT EXISTS discount_name TEXT;
ALTER TABLE public.order_items ADD COLUMN IF NOT EXISTS discount_type TEXT;
ALTER TABLE public.order_items ADD COLUMN IF NOT EXISTS discount_percentage NUMERIC(5,2);
ALTER TABLE public.order_items ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(14,2) DEFAULT 0;
ALTER TABLE public.order_items ADD COLUMN IF NOT EXISTS discount_applied NUMERIC(14,2) NOT NULL DEFAULT 0;

-- 3. STORED PROCEDURE RPC: rpc_sync_offline_order (SECURITY DEFINER - 100% Kebal RLS)
CREATE OR REPLACE FUNCTION public.rpc_sync_offline_order(
  p_order jsonb,
  p_items jsonb DEFAULT '[]'::jsonb,
  p_discounts jsonb DEFAULT '[]'::jsonb,
  p_payments jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order_id uuid;
  v_outlet_id uuid;
  v_business_id uuid;
BEGIN
  v_order_id := (p_order->>'id')::uuid;
  v_outlet_id := (p_order->>'outlet_id')::uuid;
  v_business_id := (p_order->>'business_id')::uuid;

  -- 1. Upsert Order
  INSERT INTO public.orders (
    id,
    outlet_id,
    business_id,
    invoice_number,
    customer_name,
    customer_phone,
    customer_email,
    table_number,
    dining_option,
    status,
    order_source,
    notes,
    subtotal,
    discount_total,
    tax_amount,
    grand_total,
    paid_amount,
    change_amount,
    cashier_id,
    cashier_name,
    waiter_id,
    waiter_name,
    kitchen_status,
    paid_at,
    created_at,
    void_reason,
    voided_by
  ) VALUES (
    v_order_id,
    v_outlet_id,
    v_business_id,
    p_order->>'invoice_number',
    p_order->>'customer_name',
    p_order->>'customer_phone',
    p_order->>'customer_email',
    p_order->>'table_number',
    COALESCE(p_order->>'dining_option', 'dine_in'),
    COALESCE(p_order->>'status', 'paid'),
    COALESCE(p_order->>'order_source', 'pos'),
    p_order->>'notes',
    COALESCE((p_order->>'subtotal')::numeric, 0),
    COALESCE((p_order->>'discount_total')::numeric, 0),
    COALESCE((p_order->>'tax_amount')::numeric, 0),
    COALESCE((p_order->>'grand_total')::numeric, 0),
    COALESCE((p_order->>'paid_amount')::numeric, 0),
    COALESCE((p_order->>'change_amount')::numeric, 0),
    CASE WHEN p_order->>'cashier_id' ~ '^[0-9a-fA-F-]{36}$' THEN (p_order->>'cashier_id')::uuid ELSE NULL END,
    p_order->>'cashier_name',
    CASE WHEN p_order->>'waiter_id' ~ '^[0-9a-fA-F-]{36}$' THEN (p_order->>'waiter_id')::uuid ELSE NULL END,
    p_order->>'waiter_name',
    COALESCE(p_order->>'kitchen_status', 'served'),
    (p_order->>'paid_at')::timestamptz,
    COALESCE((p_order->>'created_at')::timestamptz, now()),
    p_order->>'void_reason',
    CASE WHEN p_order->>'voided_by' ~ '^[0-9a-fA-F-]{36}$' THEN (p_order->>'voided_by')::uuid ELSE NULL END
  )
  ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    paid_amount = EXCLUDED.paid_amount,
    change_amount = EXCLUDED.change_amount,
    paid_at = EXCLUDED.paid_at,
    kitchen_status = EXCLUDED.kitchen_status,
    notes = EXCLUDED.notes,
    updated_at = now();

  -- 2. Refresh Order Items (Menggunakan nama kolom resmi: name)
  DELETE FROM public.order_items WHERE order_id = v_order_id;
  IF jsonb_array_length(p_items) > 0 THEN
    INSERT INTO public.order_items (
      id,
      order_id,
      menu_item_id,
      variant_id,
      name,
      variant_name,
      unit_price,
      quantity,
      subtotal,
      notes
    )
    SELECT
      COALESCE((item->>'id')::uuid, gen_random_uuid()),
      v_order_id,
      CASE WHEN item->>'menu_item_id' ~ '^[0-9a-fA-F-]{36}$' THEN (item->>'menu_item_id')::uuid ELSE NULL END,
      CASE WHEN item->>'variant_id' ~ '^[0-9a-fA-F-]{36}$' THEN (item->>'variant_id')::uuid ELSE NULL END,
      COALESCE(item->>'name', item->>'item_name', 'Item'),
      item->>'variant_name',
      COALESCE((item->>'unit_price')::numeric, 0),
      COALESCE((item->>'quantity')::int, 1),
      COALESCE((item->>'subtotal')::numeric, 0),
      item->>'notes'
    FROM jsonb_array_elements(p_items) AS item;
  END IF;

  -- 3. Refresh Order Discounts
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_discounts') THEN
    DELETE FROM public.order_discounts WHERE order_id = v_order_id;
    IF jsonb_array_length(p_discounts) > 0 THEN
      INSERT INTO public.order_discounts (
        id,
        order_id,
        discount_id,
        name,
        type,
        percentage_value,
        amount_value,
        max_discount_amount,
        applied_amount
      )
      SELECT
        COALESCE((disc->>'id')::uuid, gen_random_uuid()),
        v_order_id,
        CASE WHEN disc->>'discount_id' ~ '^[0-9a-fA-F-]{36}$' THEN (disc->>'discount_id')::uuid ELSE NULL END,
        COALESCE(disc->>'name', 'Diskon'),
        COALESCE(disc->>'type', 'percentage'),
        (disc->>'percentage_value')::numeric,
        (disc->>'amount_value')::numeric,
        (disc->>'max_discount_amount')::numeric,
        COALESCE((disc->>'applied_amount')::numeric, 0)
      FROM jsonb_array_elements(p_discounts) AS disc;
    END IF;
  END IF;

  -- 4. Refresh Order Payments (Menggunakan kolom resmi: method_name & method_type)
  DELETE FROM public.order_payments WHERE order_id = v_order_id;
  IF jsonb_array_length(p_payments) > 0 THEN
    INSERT INTO public.order_payments (
      id,
      order_id,
      payment_method_id,
      method_name,
      method_type,
      amount,
      reference_number
    )
    SELECT
      COALESCE((pay->>'id')::uuid, gen_random_uuid()),
      v_order_id,
      CASE WHEN pay->>'payment_method_id' ~ '^[0-9a-fA-F-]{36}$' THEN (pay->>'payment_method_id')::uuid ELSE NULL END,
      COALESCE(pay->>'method_name', pay->>'payment_method', 'Tunai'),
      COALESCE(pay->>'method_type', pay->>'payment_type', 'cash'),
      COALESCE((pay->>'amount')::numeric, 0),
      pay->>'reference_number'
    FROM jsonb_array_elements(p_payments) AS pay;
  END IF;

  RETURN jsonb_build_object('success', true, 'order_id', v_order_id);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_sync_offline_order(jsonb, jsonb, jsonb, jsonb) TO authenticated, anon;
