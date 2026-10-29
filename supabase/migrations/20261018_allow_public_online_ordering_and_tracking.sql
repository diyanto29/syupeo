-- ==============================================================================
-- IZINKAN PELANGGAN PUBLIK (ANON) MEMBUAT DAN MELACAK PESANAN ONLINE
-- ==============================================================================
-- Mendukung guest checkout tanpa login untuk link toko publik (/s/:slug),
-- order_source = 'online' & 'qr_self_order', serta live tracking pesanan.
-- ==============================================================================

-- 1. Izinkan insert pesanan online & self-order oleh anon / authenticated
DROP POLICY IF EXISTS "orders_insert_self_service" ON public.orders;
CREATE POLICY "orders_insert_self_service" ON public.orders
FOR INSERT TO anon, authenticated
WITH CHECK (
  order_source IN ('qr_self_order', 'online')
  AND status IN ('confirmed', 'draft')
  AND cashier_id IS NULL
  AND waiter_id IS NULL
  AND paid_at IS NULL
);

-- 2. Izinkan insert item pesanan untuk pesanan online & self-order
DROP POLICY IF EXISTS "order_items_insert_self_service" ON public.order_items;
CREATE POLICY "order_items_insert_self_service" ON public.order_items
FOR INSERT TO anon, authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = order_id
      AND o.order_source IN ('qr_self_order', 'online')
  )
);

-- 3. Izinkan pembacaan (SELECT) pesanan online & self-order untuk pelacakan status pesanan
DROP POLICY IF EXISTS "orders_select_public_tracking" ON public.orders;
CREATE POLICY "orders_select_public_tracking" ON public.orders
FOR SELECT TO anon, authenticated
USING (
  order_source IN ('qr_self_order', 'online')
);

-- 4. Izinkan pembacaan (SELECT) rincian item pesanan untuk pelacakan
DROP POLICY IF EXISTS "order_items_select_public_tracking" ON public.order_items;
CREATE POLICY "order_items_select_public_tracking" ON public.order_items
FOR SELECT TO anon, authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = order_items.order_id
      AND o.order_source IN ('qr_self_order', 'online')
  )
);
