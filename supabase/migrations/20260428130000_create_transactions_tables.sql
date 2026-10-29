-- =============================================================
-- TRANSACTION MODULE: orders, order_items, order_discounts, order_payments
-- =============================================================

-- ─── ENUM: order_status ──────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'order_status'
  ) THEN
    CREATE TYPE public.order_status AS ENUM (
      'draft',        -- Belum bayar, masih bisa edit
      'confirmed',    -- Sudah dikonfirmasi, menunggu bayar
      'paid',         -- Sudah lunas
      'partial_paid', -- Sebagian dibayar
      'void',         -- Dibatalkan
      'refunded'      -- Dikembalikan
    );
  END IF;
END $$;

-- ─── TABLE: orders ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  invoice_number TEXT NOT NULL,
  customer_name TEXT,
  customer_phone TEXT,
  customer_email TEXT,
  table_number INT,
  status public.order_status NOT NULL DEFAULT 'draft',
  notes TEXT,
  subtotal NUMERIC(14,2) NOT NULL DEFAULT 0,
  discount_total NUMERIC(14,2) NOT NULL DEFAULT 0,
  tax_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  grand_total NUMERIC(14,2) NOT NULL DEFAULT 0,
  paid_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  change_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  cashier_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  paid_at TIMESTAMPTZ,
  CONSTRAINT orders_invoice_not_blank CHECK (btrim(invoice_number) <> ''),
  CONSTRAINT orders_subtotal_positive CHECK (subtotal >= 0),
  CONSTRAINT orders_grand_total_positive CHECK (grand_total >= 0)
);

COMMENT ON TABLE public.orders IS
  'Transaksi utama per outlet. Bisa draft (belum bayar) atau langsung paid.';

COMMENT ON COLUMN public.orders.status IS
  'Status order: draft=belum bayar, confirmed=tunggu bayar, paid=lunas, void=batal.';

CREATE INDEX IF NOT EXISTS orders_outlet_idx ON public.orders (outlet_id);
CREATE INDEX IF NOT EXISTS orders_business_idx ON public.orders (business_id);
CREATE INDEX IF NOT EXISTS orders_status_idx ON public.orders (outlet_id, status);
CREATE INDEX IF NOT EXISTS orders_created_idx ON public.orders (outlet_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS orders_invoice_unique_idx ON public.orders (outlet_id, invoice_number);

-- ─── TABLE: order_items ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  menu_item_id UUID REFERENCES public.menu_items(id) ON DELETE SET NULL,
  variant_id UUID REFERENCES public.menu_item_variants(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  variant_name TEXT,
  quantity INT NOT NULL DEFAULT 1,
  unit_price NUMERIC(14,2) NOT NULL DEFAULT 0,
  subtotal NUMERIC(14,2) NOT NULL DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT order_items_name_not_blank CHECK (btrim(name) <> ''),
  CONSTRAINT order_items_quantity_positive CHECK (quantity > 0),
  CONSTRAINT order_items_price_positive CHECK (unit_price >= 0)
);

CREATE INDEX IF NOT EXISTS order_items_order_idx ON public.order_items (order_id);

-- ─── TABLE: order_discounts ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.order_discounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  discount_id UUID REFERENCES public.discounts(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  type public.discount_type NOT NULL,
  percentage_value NUMERIC(5,2),
  amount_value NUMERIC(14,2),
  max_discount_amount NUMERIC(14,2),
  applied_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT order_discounts_name_not_blank CHECK (btrim(name) <> '')
);

CREATE INDEX IF NOT EXISTS order_discounts_order_idx ON public.order_discounts (order_id);

-- ─── TABLE: order_payments ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.order_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  payment_method_id UUID REFERENCES public.outlet_payment_methods(id) ON DELETE SET NULL,
  method_name TEXT NOT NULL,
  method_type public.payment_method_type NOT NULL DEFAULT 'cash',
  amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  reference_number TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT order_payments_amount_positive CHECK (amount > 0)
);

CREATE INDEX IF NOT EXISTS order_payments_order_idx ON public.order_payments (order_id);

-- ─── TRIGGERS: updated_at ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = timezone('utc', now());
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_orders_updated_at ON public.orders;
CREATE TRIGGER set_orders_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ─── FUNCTION: generate invoice number ───────────────────────
CREATE OR REPLACE FUNCTION public.generate_invoice_number(
  target_outlet_id UUID
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  today_date TEXT;
  seq INT;
  result TEXT;
BEGIN
  today_date := to_char(timezone('Asia/Jakarta', now()), 'YYYYMMDD');

  SELECT COUNT(*) + 1
  INTO seq
  FROM public.orders
  WHERE outlet_id = target_outlet_id
    AND created_at >= (date_trunc('day', timezone('Asia/Jakarta', now())) AT TIME ZONE 'Asia/Jakarta')
    AND created_at < ((date_trunc('day', timezone('Asia/Jakarta', now())) + interval '1 day') AT TIME ZONE 'Asia/Jakarta');

  result := 'INV-' || today_date || '-' || lpad(seq::text, 4, '0');
  RETURN result;
END;
$$;

-- ─── RLS: orders ─────────────────────────────────────────────
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "orders_select_related" ON public.orders;
CREATE POLICY "orders_select_related" ON public.orders
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = orders.outlet_id
      AND (
        public.is_business_owner(o.business_id)
        OR public.is_business_member(o.business_id, auth.uid())
        OR EXISTS (
          SELECT 1 FROM public.outlet_members om
          WHERE om.outlet_id = o.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
        )
      )
  )
);

DROP POLICY IF EXISTS "orders_manage_related" ON public.orders;
CREATE POLICY "orders_manage_related" ON public.orders
FOR ALL TO authenticated
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
            AND bm.role IN ('owner', 'admin', 'cashier')
        )
        OR EXISTS (
          SELECT 1 FROM public.outlet_members om
          WHERE om.outlet_id = o.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role IN ('owner', 'admin', 'cashier')
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
            AND bm.role IN ('owner', 'admin', 'cashier')
        )
        OR EXISTS (
          SELECT 1 FROM public.outlet_members om
          WHERE om.outlet_id = o.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role IN ('owner', 'admin', 'cashier')
        )
      )
  )
);

-- ─── RLS: order_items ────────────────────────────────────────
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "order_items_select" ON public.order_items;
CREATE POLICY "order_items_select" ON public.order_items
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = order_items.order_id
      AND EXISTS (
        SELECT 1 FROM public.outlets ol
        WHERE ol.id = o.outlet_id
          AND (
            public.is_business_owner(ol.business_id)
            OR public.is_business_member(ol.business_id, auth.uid())
            OR EXISTS (
              SELECT 1 FROM public.outlet_members om
              WHERE om.outlet_id = ol.id AND om.user_id = auth.uid() AND om.status = 'active'
            )
          )
      )
  )
);

DROP POLICY IF EXISTS "order_items_manage" ON public.order_items;
CREATE POLICY "order_items_manage" ON public.order_items
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = order_items.order_id
      AND EXISTS (
        SELECT 1 FROM public.outlets ol
        WHERE ol.id = o.outlet_id
          AND (
            public.is_business_owner(ol.business_id)
            OR EXISTS (
              SELECT 1 FROM public.business_members bm
              WHERE bm.business_id = ol.business_id AND bm.user_id = auth.uid()
                AND bm.status = 'active' AND bm.role IN ('owner','admin','cashier')
            )
            OR EXISTS (
              SELECT 1 FROM public.outlet_members om
              WHERE om.outlet_id = ol.id AND om.user_id = auth.uid()
                AND om.status = 'active' AND om.role IN ('owner','admin','cashier')
            )
          )
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = order_items.order_id
      AND EXISTS (
        SELECT 1 FROM public.outlets ol
        WHERE ol.id = o.outlet_id
          AND (
            public.is_business_owner(ol.business_id)
            OR EXISTS (
              SELECT 1 FROM public.business_members bm
              WHERE bm.business_id = ol.business_id AND bm.user_id = auth.uid()
                AND bm.status = 'active' AND bm.role IN ('owner','admin','cashier')
            )
            OR EXISTS (
              SELECT 1 FROM public.outlet_members om
              WHERE om.outlet_id = ol.id AND om.user_id = auth.uid()
                AND om.status = 'active' AND om.role IN ('owner','admin','cashier')
            )
          )
      )
  )
);

-- ─── RLS: order_discounts ────────────────────────────────────
ALTER TABLE public.order_discounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "order_discounts_select" ON public.order_discounts;
CREATE POLICY "order_discounts_select" ON public.order_discounts
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = order_discounts.order_id
      AND EXISTS (
        SELECT 1 FROM public.outlets ol
        WHERE ol.id = o.outlet_id
          AND (
            public.is_business_owner(ol.business_id)
            OR public.is_business_member(ol.business_id, auth.uid())
            OR EXISTS (
              SELECT 1 FROM public.outlet_members om
              WHERE om.outlet_id = ol.id AND om.user_id = auth.uid() AND om.status = 'active'
            )
          )
      )
  )
);

DROP POLICY IF EXISTS "order_discounts_manage" ON public.order_discounts;
CREATE POLICY "order_discounts_manage" ON public.order_discounts
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders o WHERE o.id = order_discounts.order_id
      AND EXISTS (
        SELECT 1 FROM public.outlets ol WHERE ol.id = o.outlet_id
          AND (
            public.is_business_owner(ol.business_id)
            OR EXISTS (SELECT 1 FROM public.business_members bm WHERE bm.business_id = ol.business_id AND bm.user_id = auth.uid() AND bm.status = 'active' AND bm.role IN ('owner','admin','cashier'))
            OR EXISTS (SELECT 1 FROM public.outlet_members om WHERE om.outlet_id = ol.id AND om.user_id = auth.uid() AND om.status = 'active' AND om.role IN ('owner','admin','cashier'))
          )
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.orders o WHERE o.id = order_discounts.order_id
      AND EXISTS (
        SELECT 1 FROM public.outlets ol WHERE ol.id = o.outlet_id
          AND (
            public.is_business_owner(ol.business_id)
            OR EXISTS (SELECT 1 FROM public.business_members bm WHERE bm.business_id = ol.business_id AND bm.user_id = auth.uid() AND bm.status = 'active' AND bm.role IN ('owner','admin','cashier'))
            OR EXISTS (SELECT 1 FROM public.outlet_members om WHERE om.outlet_id = ol.id AND om.user_id = auth.uid() AND om.status = 'active' AND om.role IN ('owner','admin','cashier'))
          )
      )
  )
);

-- ─── RLS: order_payments ─────────────────────────────────────
ALTER TABLE public.order_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "order_payments_select" ON public.order_payments;
CREATE POLICY "order_payments_select" ON public.order_payments
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders o WHERE o.id = order_payments.order_id
      AND EXISTS (
        SELECT 1 FROM public.outlets ol WHERE ol.id = o.outlet_id
          AND (
            public.is_business_owner(ol.business_id)
            OR public.is_business_member(ol.business_id, auth.uid())
            OR EXISTS (SELECT 1 FROM public.outlet_members om WHERE om.outlet_id = ol.id AND om.user_id = auth.uid() AND om.status = 'active')
          )
      )
  )
);

DROP POLICY IF EXISTS "order_payments_manage" ON public.order_payments;
CREATE POLICY "order_payments_manage" ON public.order_payments
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders o WHERE o.id = order_payments.order_id
      AND EXISTS (
        SELECT 1 FROM public.outlets ol WHERE ol.id = o.outlet_id
          AND (
            public.is_business_owner(ol.business_id)
            OR EXISTS (SELECT 1 FROM public.business_members bm WHERE bm.business_id = ol.business_id AND bm.user_id = auth.uid() AND bm.status = 'active' AND bm.role IN ('owner','admin','cashier'))
            OR EXISTS (SELECT 1 FROM public.outlet_members om WHERE om.outlet_id = ol.id AND om.user_id = auth.uid() AND om.status = 'active' AND om.role IN ('owner','admin','cashier'))
          )
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.orders o WHERE o.id = order_payments.order_id
      AND EXISTS (
        SELECT 1 FROM public.outlets ol WHERE ol.id = o.outlet_id
          AND (
            public.is_business_owner(ol.business_id)
            OR EXISTS (SELECT 1 FROM public.business_members bm WHERE bm.business_id = ol.business_id AND bm.user_id = auth.uid() AND bm.status = 'active' AND bm.role IN ('owner','admin','cashier'))
            OR EXISTS (SELECT 1 FROM public.outlet_members om WHERE om.outlet_id = ol.id AND om.user_id = auth.uid() AND om.status = 'active' AND om.role IN ('owner','admin','cashier'))
          )
      )
  )
);
