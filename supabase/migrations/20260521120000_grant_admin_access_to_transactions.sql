-- ====================================================================
-- Migration: Grant Admin Read Access to Orders, Outlets, and Payments
-- Date: 2026-05-21
-- Enables Platform GMV & Transaction Monitoring in Admin Web
-- ====================================================================

-- 1. Orders
DROP POLICY IF EXISTS "Allow admins to select all orders" ON public.orders;
CREATE POLICY "Allow admins to select all orders" ON public.orders
FOR SELECT TO authenticated
USING (
  public.is_admin()
);

-- 2. Outlets
DROP POLICY IF EXISTS "Allow admins to select all outlets" ON public.outlets;
CREATE POLICY "Allow admins to select all outlets" ON public.outlets
FOR SELECT TO authenticated
USING (
  public.is_admin()
);

-- 3. Order Items
DROP POLICY IF EXISTS "Allow admins to select all order_items" ON public.order_items;
CREATE POLICY "Allow admins to select all order_items" ON public.order_items
FOR SELECT TO authenticated
USING (
  public.is_admin()
);

-- 4. Order Payments
DROP POLICY IF EXISTS "Allow admins to select all order_payments" ON public.order_payments;
CREATE POLICY "Allow admins to select all order_payments" ON public.order_payments
FOR SELECT TO authenticated
USING (
  public.is_admin()
);
