-- =============================================================
-- Enable customers to create self-orders via QR Code (Anonymous)
-- =============================================================

-- 1. Allow anyone (including anon) to read menu items and outlets (needed for the web menu)
DROP POLICY IF EXISTS "allow_anon_read_outlets" ON public.outlets;
CREATE POLICY "allow_anon_read_outlets" ON public.outlets
FOR SELECT TO anon, authenticated
USING (is_active = true);

DROP POLICY IF EXISTS "allow_anon_read_menu_items" ON public.menu_items;
CREATE POLICY "allow_anon_read_menu_items" ON public.menu_items
FOR SELECT TO anon, authenticated
USING (stock_available = true);

DROP POLICY IF EXISTS "allow_anon_read_menu_categories" ON public.menu_categories;
CREATE POLICY "allow_anon_read_menu_categories" ON public.menu_categories
FOR SELECT TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS "allow_anon_read_menu_variants" ON public.menu_item_variants;
CREATE POLICY "allow_anon_read_menu_variants" ON public.menu_item_variants
FOR SELECT TO anon, authenticated
USING (stock_available = true);

-- 2. Allow anon to INSERT into orders if order_source is qr_self_order
DROP POLICY IF EXISTS "orders_insert_self_service" ON public.orders;
CREATE POLICY "orders_insert_self_service" ON public.orders
FOR INSERT TO anon, authenticated
WITH CHECK (
  order_source = 'qr_self_order'
  AND status = 'confirmed'
  AND cashier_id IS NULL
  AND waiter_id IS NULL
  AND paid_at IS NULL
);

-- 3. Allow anon to INSERT into order_items for their own self-orders
-- Note: Simplified check to allow insert if the order is a qr_self_order
DROP POLICY IF EXISTS "order_items_insert_self_service" ON public.order_items;
CREATE POLICY "order_items_insert_self_service" ON public.order_items
FOR INSERT TO anon, authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = order_id
      AND o.order_source = 'qr_self_order'
  )
);
