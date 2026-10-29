-- Migration: 20261020_create_outlet_order_types.sql
-- Description: Create outlet_order_types table for customizable order types (Dine In, Take Away, GoFood, GrabFood, Delivery, etc.)

CREATE TABLE IF NOT EXISTS public.outlet_order_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  icon TEXT NOT NULL DEFAULT 'restaurant',
  requires_table BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  surcharge_percentage NUMERIC NOT NULL DEFAULT 0,
  surcharge_flat NUMERIC NOT NULL DEFAULT 0,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT outlet_order_types_code_not_blank CHECK (btrim(code) <> ''),
  CONSTRAINT outlet_order_types_name_not_blank CHECK (btrim(name) <> ''),
  CONSTRAINT outlet_order_types_code_format CHECK (
    code = lower(code) AND
    code ~ '^[a-z0-9][a-z0-9_]{0,62}$'
  )
);

COMMENT ON TABLE public.outlet_order_types IS
  'Daftar tipe pesanan yang dapat dikustomisasi per outlet (Dine In, Take Away, GoFood, GrabFood, Delivery, dll.)';

-- Indexes
CREATE INDEX IF NOT EXISTS outlet_order_types_outlet_id_idx
ON public.outlet_order_types (outlet_id);

CREATE INDEX IF NOT EXISTS outlet_order_types_active_idx
ON public.outlet_order_types (outlet_id, is_active, sort_order);

CREATE UNIQUE INDEX IF NOT EXISTS outlet_order_types_outlet_code_unique_idx
ON public.outlet_order_types (outlet_id, code);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS set_outlet_order_types_updated_at
ON public.outlet_order_types;
CREATE TRIGGER set_outlet_order_types_updated_at
  BEFORE UPDATE ON public.outlet_order_types
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- Function to seed default order types for an outlet
CREATE OR REPLACE FUNCTION public.seed_default_outlet_order_types(
  target_outlet_id UUID
)
RETURNS VOID
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
  INSERT INTO public.outlet_order_types (
    outlet_id,
    code,
    name,
    icon,
    requires_table,
    is_active,
    sort_order,
    surcharge_percentage,
    surcharge_flat
  )
  VALUES
    (
      target_outlet_id,
      'dine_in',
      'Makan di Tempat',
      'restaurant',
      true,
      true,
      0,
      0,
      0
    ),
    (
      target_outlet_id,
      'take_away',
      'Bawa Pulang',
      'shopping_bag',
      false,
      true,
      10,
      0,
      0
    ),
    (
      target_outlet_id,
      'gofood',
      'GoFood',
      'motorcycle',
      false,
      true,
      20,
      0,
      0
    ),
    (
      target_outlet_id,
      'grabfood',
      'GrabFood',
      'motorcycle',
      false,
      true,
      30,
      0,
      0
    ),
    (
      target_outlet_id,
      'shopeefood',
      'ShopeeFood',
      'motorcycle',
      false,
      true,
      40,
      0,
      0
    ),
    (
      target_outlet_id,
      'delivery',
      'Pesan Antar',
      'delivery_dining',
      false,
      true,
      50,
      0,
      0
    )
  ON CONFLICT (outlet_id, code) DO NOTHING;
$$;

-- Trigger to seed when a new outlet is created
CREATE OR REPLACE FUNCTION public.handle_outlet_order_types_seed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.seed_default_outlet_order_types(NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS seed_outlet_order_types_after_insert
ON public.outlets;
CREATE TRIGGER seed_outlet_order_types_after_insert
  AFTER INSERT ON public.outlets
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_outlet_order_types_seed();

-- Seed for existing outlets
SELECT public.seed_default_outlet_order_types(id)
FROM public.outlets;

-- Enable RLS
ALTER TABLE public.outlet_order_types ENABLE ROW LEVEL SECURITY;

-- Allow public read for active order types (needed by customer order & online shop)
DROP POLICY IF EXISTS "outlet_order_types_select_public"
ON public.outlet_order_types;
CREATE POLICY "outlet_order_types_select_public"
ON public.outlet_order_types
FOR SELECT
TO public
USING (true);

-- Allow authenticated owners and admins to manage order types
DROP POLICY IF EXISTS "outlet_order_types_manage_owner_admin"
ON public.outlet_order_types;
CREATE POLICY "outlet_order_types_manage_owner_admin"
ON public.outlet_order_types
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.outlets o
    WHERE o.id = outlet_order_types.outlet_id
      AND (
        public.is_business_owner(o.business_id)
        OR EXISTS (
          SELECT 1
          FROM public.business_members bm
          WHERE bm.business_id = o.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role IN ('owner', 'admin')
        )
        OR EXISTS (
          SELECT 1
          FROM public.outlet_members om
          WHERE om.outlet_id = o.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role IN ('owner', 'admin')
        )
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.outlets o
    WHERE o.id = outlet_order_types.outlet_id
      AND (
        public.is_business_owner(o.business_id)
        OR EXISTS (
          SELECT 1
          FROM public.business_members bm
          WHERE bm.business_id = o.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role IN ('owner', 'admin')
        )
        OR EXISTS (
          SELECT 1
          FROM public.outlet_members om
          WHERE om.outlet_id = o.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role IN ('owner', 'admin')
        )
      )
  )
);
