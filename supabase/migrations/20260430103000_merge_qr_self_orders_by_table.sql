-- =============================================================
-- Merge QR self-orders by outlet + QR table key into one invoice
-- =============================================================

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS self_order_table_key TEXT;

COMMENT ON COLUMN public.orders.self_order_table_key IS
  'Stable QR/self-order table key. Allows non-numeric QR labels and shared cart lookup.';

UPDATE public.orders
SET self_order_table_key = table_number::text
WHERE order_source = 'qr_self_order'
  AND self_order_table_key IS NULL
  AND table_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS orders_active_qr_self_order_table_idx
ON public.orders (outlet_id, self_order_table_key, updated_at DESC)
WHERE order_source = 'qr_self_order'
  AND status = 'confirmed'
  AND paid_at IS NULL
  AND self_order_table_key IS NOT NULL;

DROP FUNCTION IF EXISTS public.create_self_order(
  UUID,
  INTEGER,
  TEXT,
  TEXT,
  TEXT,
  JSONB
);

CREATE OR REPLACE FUNCTION public.create_self_order(
  target_outlet_id UUID,
  target_table_number INTEGER,
  target_customer_name TEXT DEFAULT NULL,
  target_customer_phone TEXT DEFAULT NULL,
  target_customer_email TEXT DEFAULT NULL,
  items_payload JSONB DEFAULT '[]'::jsonb,
  target_table_key TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  resolved_business_id UUID;
  resolved_table_key TEXT;
  requested_count INTEGER;
  calculated_subtotal NUMERIC(14,2);
  target_order_id UUID;
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

  resolved_table_key := NULLIF(
    btrim(COALESCE(target_table_key, target_table_number::text, '')),
    ''
  );

  IF resolved_table_key IS NULL THEN
    RAISE EXCEPTION 'Nomor meja QR tidak valid.';
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

  -- Keep parallel submissions from the same QR/table from creating
  -- duplicate active invoices.
  PERFORM pg_advisory_xact_lock(
    hashtext(target_outlet_id::text || ':' || resolved_table_key)
  );

  SELECT o.id
  INTO target_order_id
  FROM public.orders o
  WHERE o.outlet_id = target_outlet_id
    AND o.order_source = 'qr_self_order'
    AND o.status = 'confirmed'
    AND o.paid_at IS NULL
    AND (
      o.self_order_table_key = resolved_table_key
      OR (
        o.self_order_table_key IS NULL
        AND target_table_number IS NOT NULL
        AND o.table_number = target_table_number
      )
    )
  ORDER BY o.updated_at DESC, o.created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF target_order_id IS NULL THEN
    target_order_id := gen_random_uuid();

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
          self_order_table_key,
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
          target_order_id,
          target_outlet_id,
          resolved_business_id,
          new_invoice_number,
          NULLIF(btrim(target_customer_name), ''),
          NULLIF(btrim(target_customer_phone), ''),
          NULLIF(lower(btrim(target_customer_email)), ''),
          target_table_number,
          resolved_table_key,
          'confirmed',
          'qr_self_order',
          0,
          0,
          0,
          0,
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
  ELSE
    UPDATE public.orders
    SET
      customer_name = COALESCE(
        customer_name,
        NULLIF(btrim(target_customer_name), '')
      ),
      customer_phone = COALESCE(
        customer_phone,
        NULLIF(btrim(target_customer_phone), '')
      ),
      customer_email = COALESCE(
        customer_email,
        NULLIF(lower(btrim(target_customer_email)), '')
      ),
      self_order_table_key = resolved_table_key,
      updated_at = timezone('utc', now())
    WHERE id = target_order_id;
  END IF;

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
    target_order_id,
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

  WITH item_totals AS (
    SELECT COALESCE(SUM(oi.subtotal), 0)::NUMERIC(14,2) AS subtotal
    FROM public.order_items oi
    WHERE oi.order_id = target_order_id
  )
  UPDATE public.orders o
  SET
    subtotal = item_totals.subtotal,
    grand_total = GREATEST(
      item_totals.subtotal - o.discount_total + o.tax_amount,
      0::NUMERIC
    ),
    updated_at = timezone('utc', now())
  FROM item_totals
  WHERE o.id = target_order_id;

  RETURN target_order_id;
END;
$$;

GRANT EXECUTE
ON FUNCTION public.create_self_order(UUID, INTEGER, TEXT, TEXT, TEXT, JSONB, TEXT)
TO anon, authenticated;

DROP FUNCTION IF EXISTS public.get_self_order_history(UUID, JSONB);

CREATE OR REPLACE FUNCTION public.get_self_order_history(
  target_outlet_id UUID,
  known_order_ids JSONB DEFAULT '[]'::jsonb,
  target_table_key TEXT DEFAULT NULL,
  target_table_number INTEGER DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  resolved_table_key TEXT;
  safe_known_order_ids JSONB;
  result JSONB;
BEGIN
  resolved_table_key := NULLIF(
    btrim(COALESCE(target_table_key, target_table_number::text, '')),
    ''
  );

  IF known_order_ids IS NULL OR jsonb_typeof(known_order_ids) <> 'array' THEN
    safe_known_order_ids := '[]'::jsonb;
  ELSE
    safe_known_order_ids := known_order_ids;
  END IF;

  SELECT COALESCE(
    jsonb_agg(history_rows.order_payload ORDER BY history_rows.updated_at DESC),
    '[]'::jsonb
  )
  INTO result
  FROM (
    SELECT
      o.created_at,
      o.updated_at,
      jsonb_build_object(
        'id', o.id,
        'outlet_id', o.outlet_id,
        'business_id', o.business_id,
        'invoice_number', o.invoice_number,
        'customer_name', o.customer_name,
        'customer_phone', o.customer_phone,
        'customer_email', o.customer_email,
        'table_number', o.table_number,
        'self_order_table_key', o.self_order_table_key,
        'status', o.status,
        'order_source', o.order_source,
        'notes', o.notes,
        'subtotal', o.subtotal,
        'discount_total', o.discount_total,
        'tax_amount', o.tax_amount,
        'grand_total', o.grand_total,
        'paid_amount', o.paid_amount,
        'change_amount', o.change_amount,
        'cashier_id', o.cashier_id,
        'cashier_name', o.cashier_name,
        'waiter_id', o.waiter_id,
        'waiter_name', o.waiter_name,
        'created_at', o.created_at,
        'updated_at', o.updated_at,
        'paid_at', o.paid_at,
        'order_items', (
          SELECT COALESCE(
            jsonb_agg(
              jsonb_build_object(
                'id', oi.id,
                'menu_item_id', oi.menu_item_id,
                'variant_id', oi.variant_id,
                'name', oi.name,
                'variant_name', oi.variant_name,
                'quantity', oi.quantity,
                'unit_price', oi.unit_price,
                'subtotal', oi.subtotal,
                'notes', oi.notes,
                'discount_id', oi.discount_id,
                'discount_name', oi.discount_name,
                'discount_type', oi.discount_type,
                'discount_percentage', oi.discount_percentage,
                'discount_amount', oi.discount_amount,
                'discount_applied', oi.discount_applied
              )
              ORDER BY oi.created_at ASC
            ),
            '[]'::jsonb
          )
          FROM public.order_items oi
          WHERE oi.order_id = o.id
        ),
        'order_discounts', '[]'::jsonb,
        'order_payments', '[]'::jsonb
      ) AS order_payload
    FROM public.orders o
    WHERE o.outlet_id = target_outlet_id
      AND o.order_source = 'qr_self_order'
      AND (
        o.id IN (
          SELECT value::uuid
          FROM jsonb_array_elements_text(safe_known_order_ids)
          WHERE value ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        )
        OR (
          resolved_table_key IS NOT NULL
          AND o.status = 'confirmed'
          AND o.paid_at IS NULL
          AND (
            o.self_order_table_key = resolved_table_key
            OR (
              o.self_order_table_key IS NULL
              AND target_table_number IS NOT NULL
              AND o.table_number = target_table_number
            )
          )
        )
      )
  ) AS history_rows;

  RETURN result;
END;
$$;

GRANT EXECUTE
ON FUNCTION public.get_self_order_history(UUID, JSONB, TEXT, INTEGER)
TO anon, authenticated;
