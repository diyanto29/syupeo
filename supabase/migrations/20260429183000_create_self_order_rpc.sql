-- =============================================================
-- Self-order RPC for anonymous / web customer checkout
-- =============================================================

CREATE OR REPLACE FUNCTION public.create_self_order(
  target_outlet_id UUID,
  target_table_number INTEGER,
  target_customer_name TEXT DEFAULT NULL,
  target_customer_phone TEXT DEFAULT NULL,
  target_customer_email TEXT DEFAULT NULL,
  items_payload JSONB DEFAULT '[]'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  resolved_business_id UUID;
  requested_count INTEGER;
  calculated_subtotal NUMERIC(14,2);
  new_order_id UUID := gen_random_uuid();
  new_invoice_number TEXT;
  attempt_count INTEGER := 0;
BEGIN
  IF items_payload IS NULL
     OR jsonb_typeof(items_payload) <> 'array'
     OR jsonb_array_length(items_payload) = 0 THEN
    RAISE EXCEPTION 'Keranjang pesanan kosong.';
  END IF;

  SELECT business_id
  INTO resolved_business_id
  FROM public.outlets
  WHERE id = target_outlet_id
    AND is_active = true;

  IF resolved_business_id IS NULL THEN
    RAISE EXCEPTION 'Outlet tidak ditemukan atau sedang nonaktif.';
  END IF;

  SELECT COUNT(*)
  INTO requested_count
  FROM jsonb_to_recordset(items_payload) AS requested(
    menu_item_id UUID,
    variant_id UUID,
    quantity INTEGER,
    notes TEXT
  );

  IF requested_count = 0 THEN
    RAISE EXCEPTION 'Keranjang pesanan kosong.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_to_recordset(items_payload) AS requested(
      menu_item_id UUID,
      variant_id UUID,
      quantity INTEGER,
      notes TEXT
    )
    WHERE requested.menu_item_id IS NULL
      OR COALESCE(requested.quantity, 0) <= 0
  ) THEN
    RAISE EXCEPTION 'Data item pesanan tidak valid.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_to_recordset(items_payload) AS requested(
      menu_item_id UUID,
      variant_id UUID,
      quantity INTEGER,
      notes TEXT
    )
    LEFT JOIN public.menu_items mi
      ON mi.id = requested.menu_item_id
     AND mi.business_id = resolved_business_id
     AND mi.stock_available = true
    LEFT JOIN public.menu_item_variants mv
      ON requested.variant_id IS NOT NULL
     AND mv.id = requested.variant_id
     AND mv.menu_item_id = mi.id
     AND mv.stock_available = true
    WHERE mi.id IS NULL
       OR (requested.variant_id IS NOT NULL AND mv.id IS NULL)
  ) THEN
    RAISE EXCEPTION
      'Ada item atau varian yang sudah tidak tersedia. Silakan refresh menu lalu coba lagi.';
  END IF;

  SELECT COALESCE(SUM(COALESCE(mv.price, mi.price) * requested.quantity), 0)
  INTO calculated_subtotal
  FROM jsonb_to_recordset(items_payload) AS requested(
    menu_item_id UUID,
    variant_id UUID,
    quantity INTEGER,
    notes TEXT
  )
  JOIN public.menu_items mi
    ON mi.id = requested.menu_item_id
   AND mi.business_id = resolved_business_id
   AND mi.stock_available = true
  LEFT JOIN public.menu_item_variants mv
    ON requested.variant_id IS NOT NULL
   AND mv.id = requested.variant_id
   AND mv.menu_item_id = mi.id
   AND mv.stock_available = true;

  LOOP
    attempt_count := attempt_count + 1;
    new_invoice_number := public.generate_invoice_number(target_outlet_id);

    BEGIN
      INSERT INTO public.orders (
        id,
        outlet_id,
        business_id,
        invoice_number,
        customer_name,
        customer_phone,
        customer_email,
        table_number,
        status,
        order_source,
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
        paid_at
      )
      VALUES (
        new_order_id,
        target_outlet_id,
        resolved_business_id,
        new_invoice_number,
        NULLIF(btrim(target_customer_name), ''),
        NULLIF(btrim(target_customer_phone), ''),
        NULLIF(lower(btrim(target_customer_email)), ''),
        target_table_number,
        'confirmed',
        'qr_self_order',
        calculated_subtotal,
        0,
        0,
        calculated_subtotal,
        0,
        0,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL
      );
      EXIT;
    EXCEPTION
      WHEN unique_violation THEN
        IF attempt_count >= 5 THEN
          RAISE EXCEPTION
            'Gagal membuat nomor invoice unik untuk pesanan ini.';
        END IF;
    END;
  END LOOP;

  INSERT INTO public.order_items (
    id,
    order_id,
    menu_item_id,
    variant_id,
    name,
    variant_name,
    quantity,
    unit_price,
    subtotal,
    notes
  )
  SELECT
    gen_random_uuid(),
    new_order_id,
    requested.menu_item_id,
    requested.variant_id,
    mi.name,
    mv.name,
    requested.quantity,
    COALESCE(mv.price, mi.price),
    COALESCE(mv.price, mi.price) * requested.quantity,
    NULLIF(btrim(requested.notes), '')
  FROM jsonb_to_recordset(items_payload) AS requested(
    menu_item_id UUID,
    variant_id UUID,
    quantity INTEGER,
    notes TEXT
  )
  JOIN public.menu_items mi
    ON mi.id = requested.menu_item_id
   AND mi.business_id = resolved_business_id
   AND mi.stock_available = true
  LEFT JOIN public.menu_item_variants mv
    ON requested.variant_id IS NOT NULL
   AND mv.id = requested.variant_id
   AND mv.menu_item_id = mi.id
   AND mv.stock_available = true;

  RETURN new_order_id;
END;
$$;

GRANT EXECUTE
ON FUNCTION public.create_self_order(UUID, INTEGER, TEXT, TEXT, TEXT, JSONB)
TO anon, authenticated;
