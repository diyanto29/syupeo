-- =============================================================
-- INVENTORY SYSTEM: SUPPLIERS & PURCHASE ORDERS
-- =============================================================

-- 1. Suppliers Table
CREATE TABLE IF NOT EXISTS public.suppliers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  contact_name TEXT,
  phone TEXT,
  email TEXT,
  address TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 2. PO Status Enum
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'purchase_order_status') THEN
    CREATE TYPE public.purchase_order_status AS ENUM (
      'draft',
      'pending',
      'received',
      'cancelled'
    );
  END IF;
END $$;

-- 3. Purchase Orders Table
CREATE TABLE IF NOT EXISTS public.purchase_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL,
  po_number TEXT NOT NULL,
  status public.purchase_order_status NOT NULL DEFAULT 'draft',
  total_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
  notes TEXT,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  received_at TIMESTAMPTZ,
  
  -- Ensure PO number is unique within business
  CONSTRAINT purchase_orders_number_business_unique UNIQUE(business_id, po_number)
);

-- 4. Purchase Order Items Table
CREATE TABLE IF NOT EXISTS public.purchase_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  po_id UUID NOT NULL REFERENCES public.purchase_orders(id) ON DELETE CASCADE,
  menu_item_id UUID NOT NULL REFERENCES public.menu_items(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  received_quantity INTEGER NOT NULL DEFAULT 0 CHECK (received_quantity >= 0),
  cost_price NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (cost_price >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 5. Add 'purchase_order_receive' to inventory_movement_type if not exists
ALTER TYPE public.inventory_movement_type ADD VALUE IF NOT EXISTS 'purchase_order_receive';

-- 6. RPC Function to Receive PO
CREATE OR REPLACE FUNCTION public.receive_purchase_order(
  target_po_id UUID,
  received_items JSONB -- Array of {item_id, received_qty}
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  po_rec RECORD;
  item_rec RECORD;
  current_stock INTEGER;
  new_stock INTEGER;
BEGIN
  -- 1. Get PO details and lock for update
  SELECT * INTO po_rec 
  FROM public.purchase_orders 
  WHERE id = target_po_id 
  FOR UPDATE;

  IF po_rec IS NULL THEN
    RAISE EXCEPTION 'Purchase Order tidak ditemukan.';
  END IF;

  IF po_rec.status = 'received' THEN
    RAISE EXCEPTION 'Purchase Order sudah berstatus diterima.';
  END IF;

  IF po_rec.status = 'cancelled' THEN
    RAISE EXCEPTION 'Purchase Order sudah dibatalkan.';
  END IF;

  -- 2. Check permissions
  IF NOT public.can_manage_inventory_for_outlet(po_rec.outlet_id) THEN
    RAISE EXCEPTION 'Anda tidak punya akses untuk memproses PO ini.';
  END IF;

  -- 3. Process each item in the received_items JSON
  FOR item_rec IN SELECT * FROM jsonb_to_recordset(received_items) AS x(item_id UUID, received_qty INTEGER)
  LOOP
    -- Update received quantity in PO items
    UPDATE public.purchase_order_items
    SET received_quantity = received_quantity + item_rec.received_qty
    WHERE po_id = target_po_id AND menu_item_id = item_rec.item_id;

    -- Update stock in menu_items
    SELECT stock_quantity INTO current_stock
    FROM public.menu_items
    WHERE id = item_rec.item_id
    FOR UPDATE;

    new_stock := COALESCE(current_stock, 0) + item_rec.received_qty;

    UPDATE public.menu_items
    SET stock_quantity = new_stock
    WHERE id = item_rec.item_id;

    -- Record inventory movement
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
      reference_id,
      performed_by_user_id
    )
    VALUES (
      po_rec.business_id,
      po_rec.outlet_id,
      item_rec.item_id,
      'purchase_order_receive',
      COALESCE(current_stock, 0),
      item_rec.received_qty,
      new_stock,
      'Received from PO: ' || po_rec.po_number,
      'purchase_order',
      target_po_id,
      auth.uid()
    );
  END LOOP;

  -- 4. Update PO status
  UPDATE public.purchase_orders
  SET 
    status = 'received',
    received_at = timezone('utc', now())
  WHERE id = target_po_id;

END;
$$;

-- 7. RLS Policies
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_order_items ENABLE ROW LEVEL SECURITY;

-- Suppliers Policies
DROP POLICY IF EXISTS "suppliers_select_policy" ON public.suppliers;
CREATE POLICY "suppliers_select_policy" ON public.suppliers
FOR SELECT TO authenticated
USING (public.is_business_owner(business_id) OR public.is_business_member(business_id, auth.uid()));

DROP POLICY IF EXISTS "suppliers_insert_policy" ON public.suppliers;
CREATE POLICY "suppliers_insert_policy" ON public.suppliers
FOR INSERT TO authenticated
WITH CHECK (public.is_business_owner(business_id) OR public.is_business_member(business_id, auth.uid()));

DROP POLICY IF EXISTS "suppliers_update_policy" ON public.suppliers;
CREATE POLICY "suppliers_update_policy" ON public.suppliers
FOR UPDATE TO authenticated
USING (public.is_business_owner(business_id) OR public.is_business_member(business_id, auth.uid()));

DROP POLICY IF EXISTS "suppliers_delete_policy" ON public.suppliers;
CREATE POLICY "suppliers_delete_policy" ON public.suppliers
FOR DELETE TO authenticated
USING (public.is_business_owner(business_id));

-- PO Policies
DROP POLICY IF EXISTS "po_select_policy" ON public.purchase_orders;
CREATE POLICY "po_select_policy" ON public.purchase_orders
FOR SELECT TO authenticated
USING (
  public.is_business_owner(business_id) 
  OR public.is_business_member(business_id, auth.uid())
  OR EXISTS (
    SELECT 1 FROM public.outlet_members om 
    WHERE om.outlet_id = purchase_orders.outlet_id AND om.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "po_insert_policy" ON public.purchase_orders;
CREATE POLICY "po_insert_policy" ON public.purchase_orders
FOR INSERT TO authenticated
WITH CHECK (
  public.is_business_owner(business_id) 
  OR public.is_business_member(business_id, auth.uid())
);

DROP POLICY IF EXISTS "po_update_policy" ON public.purchase_orders;
CREATE POLICY "po_update_policy" ON public.purchase_orders
FOR UPDATE TO authenticated
USING (
  public.is_business_owner(business_id) 
  OR public.is_business_member(business_id, auth.uid())
);

-- PO Items Policies
DROP POLICY IF EXISTS "po_items_select_policy" ON public.purchase_order_items;
CREATE POLICY "po_items_select_policy" ON public.purchase_order_items
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.purchase_orders po 
    WHERE po.id = purchase_order_items.po_id
    AND (
      public.is_business_owner(po.business_id) 
      OR public.is_business_member(po.business_id, auth.uid())
      OR EXISTS (
        SELECT 1 FROM public.outlet_members om 
        WHERE om.outlet_id = po.outlet_id AND om.user_id = auth.uid()
      )
    )
  )
);

DROP POLICY IF EXISTS "po_items_insert_policy" ON public.purchase_order_items;
CREATE POLICY "po_items_insert_policy" ON public.purchase_order_items
FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.purchase_orders po 
    WHERE po.id = purchase_order_items.po_id
    AND (
      public.is_business_owner(po.business_id) 
      OR public.is_business_member(po.business_id, auth.uid())
    )
  )
);

DROP POLICY IF EXISTS "po_items_update_policy" ON public.purchase_order_items;
CREATE POLICY "po_items_update_policy" ON public.purchase_order_items
FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.purchase_orders po 
    WHERE po.id = purchase_order_items.po_id
    AND (
      public.is_business_owner(po.business_id) 
      OR public.is_business_member(po.business_id, auth.uid())
    )
  )
);

GRANT ALL ON public.suppliers TO authenticated;
GRANT ALL ON public.purchase_orders TO authenticated;
GRANT ALL ON public.purchase_order_items TO authenticated;
GRANT EXECUTE ON FUNCTION public.receive_purchase_order(UUID, JSONB) TO authenticated;
