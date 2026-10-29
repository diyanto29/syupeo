-- =============================================================
-- SHARED CART SYSTEM: Manage draft orders for QR/Self-Ordering
-- =============================================================

-- 1. Function to Sync Draft Cart (Add/Update Items)
CREATE OR REPLACE FUNCTION public.sync_self_order_draft(
  target_outlet_id UUID,
  target_table_number INTEGER,
  items_payload JSONB -- Array of {menu_item_id, variant_id, quantity, notes}
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  resolved_business_id UUID;
  target_order_id UUID;
  new_invoice_number TEXT;
BEGIN
  -- Get business ID
  SELECT business_id INTO resolved_business_id FROM public.outlets WHERE id = target_outlet_id;
  
  -- Find existing DRAFT order for this table
  SELECT id INTO target_order_id 
  FROM public.orders 
  WHERE outlet_id = target_outlet_id 
    AND table_number = target_table_number 
    AND status = 'draft' 
    AND order_source = 'qr_self_order'
  LIMIT 1;

  -- If no draft exists, create a new one
  IF target_order_id IS NULL THEN
    target_order_id := gen_random_uuid();
    new_invoice_number := public.generate_invoice_number(target_outlet_id);
    
    INSERT INTO public.orders (
      id, outlet_id, business_id, invoice_number, table_number, status, order_source
    ) VALUES (
      target_order_id, target_outlet_id, resolved_business_id, new_invoice_number, target_table_number, 'draft', 'qr_self_order'
    );
  END IF;

  -- Clear existing items in draft
  DELETE FROM public.order_items WHERE order_id = target_order_id;

  -- Insert new items from payload
  INSERT INTO public.order_items (
    order_id, menu_item_id, variant_id, name, variant_name, quantity, unit_price, subtotal, notes
  )
  SELECT 
    target_order_id,
    requested.menu_item_id,
    requested.variant_id,
    mi.name,
    mv.name,
    requested.quantity,
    COALESCE(mv.price, mi.price),
    COALESCE(mv.price, mi.price) * requested.quantity,
    requested.notes
  FROM jsonb_to_recordset(items_payload) AS requested(
    menu_item_id UUID, variant_id UUID, quantity INTEGER, notes TEXT
  )
  JOIN public.menu_items mi ON mi.id = requested.menu_item_id
  LEFT JOIN public.menu_item_variants mv ON mv.id = requested.variant_id;

  -- Update order totals
  UPDATE public.orders 
  SET 
    subtotal = (SELECT SUM(subtotal) FROM public.order_items WHERE order_id = target_order_id),
    grand_total = (SELECT SUM(subtotal) FROM public.order_items WHERE order_id = target_order_id),
    updated_at = now()
  WHERE id = target_order_id;

  RETURN target_order_id;
END;
$$;

-- 2. Function to Confirm Order (Change Draft to Confirmed)
CREATE OR REPLACE FUNCTION public.confirm_self_order_draft(
  target_order_id UUID,
  target_customer_name TEXT,
  target_customer_phone TEXT DEFAULT NULL,
  target_order_notes TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.orders 
  SET 
    status = 'confirmed',
    customer_name = target_customer_name,
    customer_phone = target_customer_phone,
    notes = target_order_notes,
    updated_at = now()
  WHERE id = target_order_id AND status = 'draft';
END;
$$;

-- 3. Grant Access
GRANT EXECUTE ON FUNCTION public.sync_self_order_draft(UUID, INTEGER, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_self_order_draft(UUID, TEXT, TEXT, TEXT) TO anon, authenticated;
