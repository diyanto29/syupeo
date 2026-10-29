-- =============================================================
-- Public self-order history lookup for customer web
-- =============================================================

CREATE OR REPLACE FUNCTION public.get_self_order_history(
  target_outlet_id UUID,
  known_order_ids JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSONB;
BEGIN
  IF known_order_ids IS NULL
     OR jsonb_typeof(known_order_ids) <> 'array'
     OR jsonb_array_length(known_order_ids) = 0 THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT COALESCE(
    jsonb_agg(history_rows.order_payload ORDER BY history_rows.created_at DESC),
    '[]'::jsonb
  )
  INTO result
  FROM (
    SELECT
      o.created_at,
      jsonb_build_object(
        'id', o.id,
        'outlet_id', o.outlet_id,
        'business_id', o.business_id,
        'invoice_number', o.invoice_number,
        'customer_name', o.customer_name,
        'customer_phone', o.customer_phone,
        'customer_email', o.customer_email,
        'table_number', o.table_number,
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
      AND o.id IN (
        SELECT value::uuid
        FROM jsonb_array_elements_text(known_order_ids)
      )
  ) AS history_rows;

  RETURN result;
END;
$$;

GRANT EXECUTE
ON FUNCTION public.get_self_order_history(UUID, JSONB)
TO anon, authenticated;
