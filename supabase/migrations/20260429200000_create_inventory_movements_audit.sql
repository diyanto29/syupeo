-- =============================================================
-- INVENTORY AUDIT TRAIL
-- Records every tracked stock change with date/time and actor.
-- Current stock snapshot remains on public.menu_items.stock_quantity
-- so the existing app can adopt auditing without breaking queries.
-- =============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'inventory_movement_type'
  ) THEN
    CREATE TYPE public.inventory_movement_type AS ENUM (
      'initial_stock',
      'manual_addition',
      'manual_reduction',
      'stock_opname',
      'sale',
      'void_restore',
      'refund'
    );
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.inventory_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  menu_item_id UUID NOT NULL REFERENCES public.menu_items(id) ON DELETE CASCADE,
  movement_type public.inventory_movement_type NOT NULL,
  quantity_before INTEGER NOT NULL,
  quantity_delta INTEGER NOT NULL,
  quantity_after INTEGER NOT NULL,
  note TEXT,
  reference_type TEXT,
  reference_id UUID,
  performed_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT inventory_movements_quantity_before_nonnegative
    CHECK (quantity_before >= 0),
  CONSTRAINT inventory_movements_quantity_after_nonnegative
    CHECK (quantity_after >= 0),
  CONSTRAINT inventory_movements_quantity_delta_nonzero
    CHECK (quantity_delta <> 0),
  CONSTRAINT inventory_movements_quantity_consistent
    CHECK (quantity_after = quantity_before + quantity_delta)
);

COMMENT ON TABLE public.inventory_movements IS
  'Audit trail untuk setiap perubahan stok item menu, termasuk tanggal/jam, outlet, dan pelakunya.';

COMMENT ON COLUMN public.inventory_movements.created_at IS
  'Waktu perubahan stok tercatat dalam UTC. Gunakan konversi timezone di client bila perlu.';

COMMENT ON COLUMN public.inventory_movements.note IS
  'Catatan bebas, misalnya alasan restock atau koreksi stok.';

CREATE INDEX IF NOT EXISTS inventory_movements_menu_item_created_idx
  ON public.inventory_movements (menu_item_id, created_at DESC);

CREATE INDEX IF NOT EXISTS inventory_movements_outlet_created_idx
  ON public.inventory_movements (outlet_id, created_at DESC);

CREATE INDEX IF NOT EXISTS inventory_movements_business_created_idx
  ON public.inventory_movements (business_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.can_manage_inventory_for_outlet(
  target_outlet_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target_business_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  SELECT o.business_id
  INTO target_business_id
  FROM public.outlets o
  WHERE o.id = target_outlet_id;

  IF target_business_id IS NULL THEN
    RETURN false;
  END IF;

  RETURN
    public.is_business_owner(target_business_id)
    OR EXISTS (
      SELECT 1
      FROM public.business_members bm
      WHERE bm.business_id = target_business_id
        AND bm.user_id = auth.uid()
        AND bm.status = 'active'
        AND bm.role IN ('owner', 'admin')
    )
    OR EXISTS (
      SELECT 1
      FROM public.outlet_members om
      WHERE om.outlet_id = target_outlet_id
        AND om.user_id = auth.uid()
        AND om.status = 'active'
        AND om.role IN ('owner', 'admin')
    );
END;
$$;

REVOKE ALL ON FUNCTION public.can_manage_inventory_for_outlet(UUID) FROM public;
GRANT EXECUTE ON FUNCTION public.can_manage_inventory_for_outlet(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.adjust_menu_item_stock(
  target_menu_item_id UUID,
  target_outlet_id UUID,
  target_new_quantity INTEGER,
  target_note TEXT DEFAULT NULL,
  target_reference_type TEXT DEFAULT 'manual_adjustment'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  item_business_id UUID;
  current_quantity INTEGER;
  quantity_delta INTEGER;
  movement_kind public.inventory_movement_type;
  movement_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Anda harus login untuk mengubah stok.';
  END IF;

  IF target_menu_item_id IS NULL THEN
    RAISE EXCEPTION 'Produk tujuan wajib diisi.';
  END IF;

  IF target_outlet_id IS NULL THEN
    RAISE EXCEPTION 'Outlet tujuan wajib diisi.';
  END IF;

  IF target_new_quantity IS NULL OR target_new_quantity < 0 THEN
    RAISE EXCEPTION 'Stok baru tidak boleh negatif.';
  END IF;

  IF NOT public.can_manage_inventory_for_outlet(target_outlet_id) THEN
    RAISE EXCEPTION 'Anda tidak punya akses untuk mengubah stok outlet ini.';
  END IF;

  SELECT mi.business_id, COALESCE(mi.stock_quantity, 0)
  INTO item_business_id, current_quantity
  FROM public.menu_items mi
  JOIN public.outlets o
    ON o.id = target_outlet_id
   AND o.business_id = mi.business_id
  WHERE mi.id = target_menu_item_id
  FOR UPDATE;

  IF item_business_id IS NULL THEN
    RAISE EXCEPTION 'Produk tidak ditemukan pada outlet yang dipilih.';
  END IF;

  IF current_quantity = target_new_quantity THEN
    RETURN NULL;
  END IF;

  quantity_delta := target_new_quantity - current_quantity;

  IF current_quantity = 0
     AND target_new_quantity > 0
     AND NOT EXISTS (
       SELECT 1
       FROM public.inventory_movements im
       WHERE im.menu_item_id = target_menu_item_id
         AND im.outlet_id = target_outlet_id
     ) THEN
    movement_kind := 'initial_stock';
  ELSIF quantity_delta > 0 THEN
    movement_kind := 'manual_addition';
  ELSE
    movement_kind := 'manual_reduction';
  END IF;

  UPDATE public.menu_items
  SET stock_quantity = target_new_quantity
  WHERE id = target_menu_item_id;

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
    performed_by_user_id
  )
  VALUES (
    item_business_id,
    target_outlet_id,
    target_menu_item_id,
    movement_kind,
    current_quantity,
    quantity_delta,
    target_new_quantity,
    NULLIF(btrim(target_note), ''),
    NULLIF(btrim(target_reference_type), ''),
    auth.uid()
  )
  RETURNING id INTO movement_id;

  RETURN movement_id;
END;
$$;

REVOKE ALL ON FUNCTION public.adjust_menu_item_stock(UUID, UUID, INTEGER, TEXT, TEXT) FROM public;
GRANT EXECUTE ON FUNCTION public.adjust_menu_item_stock(UUID, UUID, INTEGER, TEXT, TEXT) TO authenticated;

ALTER TABLE public.inventory_movements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "inventory_movements_select_related" ON public.inventory_movements;
CREATE POLICY "inventory_movements_select_related" ON public.inventory_movements
FOR SELECT TO authenticated
USING (
  public.is_business_owner(business_id)
  OR public.is_business_member(business_id, auth.uid())
  OR EXISTS (
    SELECT 1
    FROM public.outlet_members om
    WHERE om.outlet_id = inventory_movements.outlet_id
      AND om.user_id = auth.uid()
      AND om.status = 'active'
  )
);
