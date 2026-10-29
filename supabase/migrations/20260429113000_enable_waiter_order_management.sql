-- =============================================================
-- Enable waiter to create and maintain their own unpaid orders
-- =============================================================

-- Ensure columns exist before creating policies
DO $$ 
BEGIN
  -- Add order_source if it doesn't exist (added in previous migration but just in case)
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'order_source' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.order_source AS ENUM ('pos', 'qr_self_order', 'waiter', 'online');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name='orders' AND column_name='order_source') THEN
    ALTER TABLE public.orders ADD COLUMN order_source public.order_source NOT NULL DEFAULT 'pos';
  END IF;

  -- Add waiter_id if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name='orders' AND column_name='waiter_id') THEN
    ALTER TABLE public.orders ADD COLUMN waiter_id UUID REFERENCES auth.users(id);
  END IF;

  -- Add waiter_name if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name='orders' AND column_name='waiter_name') THEN
    ALTER TABLE public.orders ADD COLUMN waiter_name text;
  END IF;
END $$;


DROP POLICY IF EXISTS "orders_manage_waiter_own_unpaid" ON public.orders;
CREATE POLICY "orders_manage_waiter_own_unpaid" ON public.orders
FOR ALL TO authenticated
USING (
  orders.order_source = 'waiter'
  AND orders.status IN ('draft', 'confirmed')
  AND orders.waiter_id = auth.uid()
  AND COALESCE(orders.paid_amount, 0) = 0
  AND COALESCE(orders.change_amount, 0) = 0
  AND orders.paid_at IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.outlets o
    WHERE o.id = orders.outlet_id
      AND (
        EXISTS (
          SELECT 1
          FROM public.business_members bm
          WHERE bm.business_id = o.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role = 'waiter'
        )
        OR EXISTS (
          SELECT 1
          FROM public.outlet_members om
          WHERE om.outlet_id = o.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role = 'waiter'
        )
      )
  )
)
WITH CHECK (
  orders.order_source = 'waiter'
  AND orders.status IN ('draft', 'confirmed')
  AND orders.waiter_id = auth.uid()
  AND COALESCE(orders.paid_amount, 0) = 0
  AND COALESCE(orders.change_amount, 0) = 0
  AND orders.paid_at IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.outlets o
    WHERE o.id = orders.outlet_id
      AND (
        EXISTS (
          SELECT 1
          FROM public.business_members bm
          WHERE bm.business_id = o.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role = 'waiter'
        )
        OR EXISTS (
          SELECT 1
          FROM public.outlet_members om
          WHERE om.outlet_id = o.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role = 'waiter'
        )
      )
  )
);

DROP POLICY IF EXISTS "order_items_manage_waiter_own_unpaid" ON public.order_items;
CREATE POLICY "order_items_manage_waiter_own_unpaid" ON public.order_items
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.orders o
    JOIN public.outlets ol ON ol.id = o.outlet_id
    WHERE o.id = order_items.order_id
      AND o.order_source = 'waiter'
      AND o.status IN ('draft', 'confirmed')
      AND o.waiter_id = auth.uid()
      AND COALESCE(o.paid_amount, 0) = 0
      AND COALESCE(o.change_amount, 0) = 0
      AND o.paid_at IS NULL
      AND (
        EXISTS (
          SELECT 1
          FROM public.business_members bm
          WHERE bm.business_id = ol.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role = 'waiter'
        )
        OR EXISTS (
          SELECT 1
          FROM public.outlet_members om
          WHERE om.outlet_id = ol.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role = 'waiter'
        )
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.orders o
    JOIN public.outlets ol ON ol.id = o.outlet_id
    WHERE o.id = order_items.order_id
      AND o.order_source = 'waiter'
      AND o.status IN ('draft', 'confirmed')
      AND o.waiter_id = auth.uid()
      AND COALESCE(o.paid_amount, 0) = 0
      AND COALESCE(o.change_amount, 0) = 0
      AND o.paid_at IS NULL
      AND (
        EXISTS (
          SELECT 1
          FROM public.business_members bm
          WHERE bm.business_id = ol.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role = 'waiter'
        )
        OR EXISTS (
          SELECT 1
          FROM public.outlet_members om
          WHERE om.outlet_id = ol.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role = 'waiter'
        )
      )
  )
);

DROP POLICY IF EXISTS "order_discounts_manage_waiter_own_unpaid" ON public.order_discounts;
CREATE POLICY "order_discounts_manage_waiter_own_unpaid" ON public.order_discounts
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.orders o
    JOIN public.outlets ol ON ol.id = o.outlet_id
    WHERE o.id = order_discounts.order_id
      AND o.order_source = 'waiter'
      AND o.status IN ('draft', 'confirmed')
      AND o.waiter_id = auth.uid()
      AND COALESCE(o.paid_amount, 0) = 0
      AND COALESCE(o.change_amount, 0) = 0
      AND o.paid_at IS NULL
      AND (
        EXISTS (
          SELECT 1
          FROM public.business_members bm
          WHERE bm.business_id = ol.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role = 'waiter'
        )
        OR EXISTS (
          SELECT 1
          FROM public.outlet_members om
          WHERE om.outlet_id = ol.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role = 'waiter'
        )
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.orders o
    JOIN public.outlets ol ON ol.id = o.outlet_id
    WHERE o.id = order_discounts.order_id
      AND o.order_source = 'waiter'
      AND o.status IN ('draft', 'confirmed')
      AND o.waiter_id = auth.uid()
      AND COALESCE(o.paid_amount, 0) = 0
      AND COALESCE(o.change_amount, 0) = 0
      AND o.paid_at IS NULL
      AND (
        EXISTS (
          SELECT 1
          FROM public.business_members bm
          WHERE bm.business_id = ol.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role = 'waiter'
        )
        OR EXISTS (
          SELECT 1
          FROM public.outlet_members om
          WHERE om.outlet_id = ol.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role = 'waiter'
        )
      )
  )
);
