-- ==============================================================================
-- SYUPEO DATABASE MIGRATION SYSTEM
-- Migration: 20261101010000_fix_stock_deduction_and_variant_cost.sql
-- Description:
-- 1. Tambah kolom cost_price pada order_items untuk pencatatan HPP akurat per varian/eceran.
-- 2. Dukung RPC adjust_menu_item_stock dengan NUMERIC (fraksi/desimal 1/2 kg = 0.5, 1/4 kg = 0.25).
-- 3. Update rpc_sync_offline_order agar otomatis memotong stok fisik di menu_items sesuai rasio varian.
-- 4. Sinkronisasi sisa stok untuk transaksi eceran yang telah tersimpan.
-- ==============================================================================

-- 1. Pastikan kolom cost_price tersedia di tabel order_items
ALTER TABLE public.order_items ADD COLUMN IF NOT EXISTS cost_price NUMERIC(14,2) DEFAULT 0;

-- 2. Pastikan kolom stock_quantity di menu_items mendukung pecahan / desimal
ALTER TABLE public.menu_items ALTER COLUMN stock_quantity TYPE NUMERIC USING stock_quantity::NUMERIC;

-- 3. Stored Procedure adjust_menu_item_stock dengan NUMERIC
CREATE OR REPLACE FUNCTION public.adjust_menu_item_stock(
  target_menu_item_id UUID,
  target_outlet_id UUID,
  target_new_quantity NUMERIC,
  target_note TEXT DEFAULT NULL,
  target_reference_type TEXT DEFAULT 'manual_adjustment'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_biz_id UUID;
  v_old_qty NUMERIC;
BEGIN
  SELECT business_id, stock_quantity INTO v_biz_id, v_old_qty
  FROM public.menu_items
  WHERE id = target_menu_item_id;

  IF v_biz_id IS NULL THEN
    RAISE EXCEPTION 'Produk tidak ditemukan.';
  END IF;

  UPDATE public.menu_items
  SET stock_quantity = target_new_quantity,
      stock_available = (target_new_quantity > 0),
      updated_at = timezone('utc', now())
  WHERE id = target_menu_item_id;

  -- Catat riwayat mutasi stok jika tabel inventory_movements ada
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'inventory_movements') THEN
    INSERT INTO public.inventory_movements (
      business_id,
      outlet_id,
      menu_item_id,
      movement_type,
      quantity_before,
      quantity_delta,
      quantity_after,
      note,
      reference_type,
      performed_by_user_id
    ) VALUES (
      v_biz_id,
      target_outlet_id,
      target_menu_item_id,
      target_reference_type,
      COALESCE(v_old_qty, 0),
      target_new_quantity - COALESCE(v_old_qty, 0),
      target_new_quantity,
      COALESCE(target_note, 'Penyesuaian stok kasir'),
      'order',
      auth.uid()
    );
  END IF;

  RETURN target_menu_item_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.adjust_menu_item_stock(UUID, UUID, NUMERIC, TEXT, TEXT) TO authenticated, service_role, anon;

-- 4. Update rpc_sync_offline_order agar otomatis memotong stok fisik saat pesanan tersinkronisasi
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
  v_status text;
  v_item record;
  v_multiplier numeric;
  v_old_stock numeric;
  v_qty_sold numeric;
BEGIN
  v_order_id := (p_order->>'id')::uuid;
  v_outlet_id := (p_order->>'outlet_id')::uuid;
  v_business_id := (p_order->>'business_id')::uuid;
  v_status := COALESCE(p_order->>'status', 'paid');

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
    v_status,
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

  -- 2. Refresh Order Items (Termasuk cost_price untuk margin laba akurat)
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
      cost_price,
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
      COALESCE((item->>'cost_price')::numeric, 0),
      COALESCE((item->>'quantity')::int, 1),
      COALESCE((item->>'subtotal')::numeric, 0),
      item->>'notes'
    FROM jsonb_array_elements(p_items) AS item;

    -- 2b. Potong stok fisik produk di menu_items jika order berstatus 'paid'
    IF v_status = 'paid' THEN
      FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        IF (v_item.value->>'menu_item_id') ~ '^[0-9a-fA-F-]{36}$' THEN
          -- Hitung rasio fraksi varian (contoh 1/2 kg = 0.5, 1/4 kg = 0.25)
          v_multiplier := 1.0;
          IF v_item.value->>'variant_name' IS NOT NULL THEN
            IF (v_item.value->>'variant_name') ILIKE '%1/2%' OR (v_item.value->>'variant_name') ILIKE '%500g%' OR (v_item.value->>'variant_name') ILIKE '%0.5%' THEN
              v_multiplier := 0.5;
            ELSIF (v_item.value->>'variant_name') ILIKE '%1/4%' OR (v_item.value->>'variant_name') ILIKE '%250g%' OR (v_item.value->>'variant_name') ILIKE '%0.25%' THEN
              v_multiplier := 0.25;
            ELSIF (v_item.value->>'variant_name') ILIKE '%3/4%' OR (v_item.value->>'variant_name') ILIKE '%750g%' OR (v_item.value->>'variant_name') ILIKE '%0.75%' THEN
              v_multiplier := 0.75;
            END IF;
          END IF;

          v_qty_sold := COALESCE((v_item.value->>'quantity')::numeric, 1) * v_multiplier;

          UPDATE public.menu_items
          SET stock_quantity = GREATEST(0, stock_quantity - v_qty_sold),
              stock_available = (stock_quantity - v_qty_sold) > 0,
              updated_at = now()
          WHERE id = (v_item.value->>'menu_item_id')::uuid
            AND track_stock_quantity = true;
        END IF;
      END LOOP;
    END IF;
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
        COALESCE(disc->>'type', 'fixed'),
        (disc->>'percentage_value')::numeric,
        (disc->>'amount_value')::numeric,
        (disc->>'max_discount_amount')::numeric,
        COALESCE((disc->>'applied_amount')::numeric, 0)
      FROM jsonb_array_elements(p_discounts) AS disc;
    END IF;
  END IF;

  -- 4. Refresh Order Payments
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
      COALESCE(pay->>'method_name', 'Tunai'),
      COALESCE(pay->>'method_type', 'cash'),
      COALESCE((pay->>'amount')::numeric, 0),
      pay->>'reference_number'
    FROM jsonb_array_elements(p_payments) AS pay;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'invoice_number', p_order->>'invoice_number'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM,
    'code', SQLSTATE
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_sync_offline_order(jsonb, jsonb, jsonb, jsonb) TO authenticated, service_role, anon;

-- 5. Koreksi Stok Gula Pasir untuk 2 transaksi 1/2 kg yang telah berhasil tersimpan
-- (2 transaksi x 0.5 kg = 1 kg terjual, sisa stok dari 2 kg menjadi 1 kg)
UPDATE public.menu_items
SET stock_quantity = GREATEST(0, stock_quantity - 1),
    updated_at = now()
WHERE name ILIKE '%Gula Pasir%'
  AND stock_quantity >= 2
  AND track_stock_quantity = true;

-- 6. Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';

