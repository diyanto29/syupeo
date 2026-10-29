-- Migration: Allow kitchen and waiter roles to update order kitchen_status and notes
-- Enables Kitchen Display System (KDS) staff to change status (pending -> cooking -> ready -> served)

-- 1. Create or update RLS policy for updating orders
DROP POLICY IF EXISTS "orders_update_kitchen_status" ON public.orders;
CREATE POLICY "orders_update_kitchen_status" ON public.orders
FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = orders.outlet_id
      AND (
        public.is_business_owner(o.business_id)
        OR EXISTS (
          SELECT 1 FROM public.business_members bm
          WHERE bm.business_id = o.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role IN ('owner', 'admin', 'cashier', 'kitchen', 'waiter')
        )
        OR EXISTS (
          SELECT 1 FROM public.outlet_members om
          WHERE om.outlet_id = o.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role IN ('owner', 'admin', 'cashier', 'kitchen', 'waiter')
        )
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = orders.outlet_id
      AND (
        public.is_business_owner(o.business_id)
        OR EXISTS (
          SELECT 1 FROM public.business_members bm
          WHERE bm.business_id = o.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role IN ('owner', 'admin', 'cashier', 'kitchen', 'waiter')
        )
        OR EXISTS (
          SELECT 1 FROM public.outlet_members om
          WHERE om.outlet_id = o.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role IN ('owner', 'admin', 'cashier', 'kitchen', 'waiter')
        )
      )
  )
);

-- 2. Create RPC function for updating kitchen order status with SECURITY DEFINER
-- This guarantees atomic, safe status transitions even when RLS has complex permission hierarchies.
CREATE OR REPLACE FUNCTION public.update_kitchen_order_status(
  p_order_id UUID,
  p_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order RECORD;
  v_user_id UUID;
  v_is_authorized BOOLEAN := FALSE;
  v_current_notes TEXT;
  v_updated_notes TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: User not authenticated';
  END IF;

  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  -- Check authorization: owner, business member, or outlet member
  SELECT EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = v_order.outlet_id
      AND (
        public.is_business_owner(o.business_id)
        OR EXISTS (
          SELECT 1 FROM public.business_members bm
          WHERE bm.business_id = o.business_id
            AND bm.user_id = v_user_id
            AND bm.status = 'active'
            AND bm.role IN ('owner', 'admin', 'cashier', 'kitchen', 'waiter')
        )
        OR EXISTS (
          SELECT 1 FROM public.outlet_members om
          WHERE om.outlet_id = o.id
            AND om.user_id = v_user_id
            AND om.status = 'active'
            AND om.role IN ('owner', 'admin', 'cashier', 'kitchen', 'waiter')
        )
      )
  ) INTO v_is_authorized;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Forbidden: User is not authorized to update orders for this outlet';
  END IF;

  -- Ensure kitchen_status column exists, then update
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'orders' 
      AND column_name = 'kitchen_status'
  ) THEN
    UPDATE public.orders
    SET 
      kitchen_status = p_status,
      updated_at = NOW()
    WHERE id = p_order_id;
  ELSE
    -- Backward-compatible fallback: update notes tag
    v_current_notes := COALESCE(v_order.notes, '');
    v_current_notes := regexp_replace(v_current_notes, '\[KITCHEN:(PENDING|COOKING|READY|SERVED)\]\s*', '', 'gi');
    v_updated_notes := TRIM('[KITCHEN:' || UPPER(p_status) || '] ' || v_current_notes);
    
    UPDATE public.orders
    SET 
      notes = v_updated_notes,
      updated_at = NOW()
    WHERE id = p_order_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'kitchen_status', p_status
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_kitchen_order_status(UUID, TEXT) TO authenticated;
