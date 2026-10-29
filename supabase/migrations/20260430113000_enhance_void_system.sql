-- 1. Add voided_by to orders
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS voided_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;
COMMENT ON COLUMN public.orders.voided_by IS 'User ID yang melakukan pembatalan (void).';

-- 2. Create Order Status Logs for Audit Trail
CREATE TABLE IF NOT EXISTS public.order_status_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    from_status public.order_status,
    to_status public.order_status NOT NULL,
    reason TEXT,
    performed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS order_status_logs_order_id_idx ON public.order_status_logs(order_id);

-- 3. Trigger Function to Log Status Changes
CREATE OR REPLACE FUNCTION public.log_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.status IS DISTINCT FROM NEW.status) THEN
        INSERT INTO public.order_status_logs (
            order_id,
            from_status,
            to_status,
            reason,
            performed_by
        ) VALUES (
            NEW.id,
            OLD.status,
            NEW.status,
            NEW.void_reason,
            NEW.voided_by
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_log_order_status_change ON public.orders;
CREATE TRIGGER tr_log_order_status_change
    AFTER UPDATE ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.log_order_status_change();

-- 4. Trigger Function to Restore Stock on Void
CREATE OR REPLACE FUNCTION public.restore_stock_on_void()
RETURNS TRIGGER AS $$
DECLARE
    item_rec RECORD;
    current_stock INTEGER;
    new_stock INTEGER;
BEGIN
    -- Trigger when status changes to 'void' or 'refunded'
    IF (OLD.status NOT IN ('void', 'refunded') AND NEW.status IN ('void', 'refunded')) THEN
        FOR item_rec IN 
            SELECT menu_item_id, quantity 
            FROM public.order_items 
            WHERE order_id = NEW.id AND menu_item_id IS NOT NULL
        LOOP
            -- Get current stock
            SELECT stock_quantity INTO current_stock
            FROM public.menu_items
            WHERE id = item_rec.menu_item_id
            FOR UPDATE;

            IF current_stock IS NOT NULL THEN
                new_stock := current_stock + item_rec.quantity;

                -- Update stock
                UPDATE public.menu_items
                SET stock_quantity = new_stock
                WHERE id = item_rec.menu_item_id;

                -- Record movement
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
                ) VALUES (
                    NEW.business_id,
                    NEW.outlet_id,
                    item_rec.menu_item_id,
                    CASE WHEN NEW.status = 'void' THEN 'void_restore' ELSE 'refund' END::public.inventory_movement_type,
                    current_stock,
                    item_rec.quantity,
                    new_stock,
                    CASE WHEN NEW.status = 'void' THEN 'Pembatalan Pesanan: ' ELSE 'Refund Pesanan: ' END || NEW.invoice_number,
                    'order',
                    NEW.id,
                    NEW.voided_by
                );
            END IF;
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_restore_stock_on_void ON public.orders;
CREATE TRIGGER tr_restore_stock_on_void
    AFTER UPDATE ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.restore_stock_on_void();

-- 5. Add RLS for order_status_logs
ALTER TABLE public.order_status_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "order_status_logs_select" ON public.order_status_logs;
CREATE POLICY "order_status_logs_select" ON public.order_status_logs
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = order_status_logs.order_id
  )
);
