DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'discount_type'
  ) THEN
    CREATE TYPE public.discount_type AS ENUM ('percentage', 'fixed_amount');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.discounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  code TEXT,
  description TEXT,
  type public.discount_type NOT NULL,
  percentage_value NUMERIC(5, 2),
  amount_value NUMERIC(14, 2),
  max_discount_amount NUMERIC(14, 2),
  is_active BOOLEAN NOT NULL DEFAULT true,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT discounts_name_not_blank CHECK (btrim(name) <> ''),
  CONSTRAINT discounts_code_not_blank CHECK (
    code IS NULL OR btrim(code) <> ''
  ),
  CONSTRAINT discounts_value_check CHECK (
    (
      type = 'percentage' AND
      percentage_value IS NOT NULL AND
      percentage_value > 0 AND
      percentage_value <= 100 AND
      amount_value IS NULL AND
      (
        max_discount_amount IS NULL OR
        max_discount_amount >= 0
      )
    ) OR (
      type = 'fixed_amount' AND
      amount_value IS NOT NULL AND
      amount_value > 0 AND
      percentage_value IS NULL AND
      max_discount_amount IS NULL
    )
  ),
  CONSTRAINT discounts_period_check CHECK (
    starts_at IS NULL OR
    ends_at IS NULL OR
    starts_at <= ends_at
  )
);

COMMENT ON TABLE public.discounts IS
  'Master metadata diskon per bisnis untuk dipakai fleksibel di item, cart, atau transaksi.';

COMMENT ON COLUMN public.discounts.type IS
  'Jenis diskon: percentage untuk persen, fixed_amount untuk potongan rupiah langsung.';

COMMENT ON COLUMN public.discounts.max_discount_amount IS
  'Batas potongan maksimal dalam rupiah, hanya berlaku untuk discount percentage.';

CREATE INDEX IF NOT EXISTS discounts_business_id_idx
ON public.discounts (business_id);

CREATE INDEX IF NOT EXISTS discounts_business_active_idx
ON public.discounts (business_id, is_active);

CREATE INDEX IF NOT EXISTS discounts_business_type_idx
ON public.discounts (business_id, type);

CREATE UNIQUE INDEX IF NOT EXISTS discounts_business_code_unique_idx
ON public.discounts (business_id, lower(code))
WHERE code IS NOT NULL AND btrim(code) <> '';

DROP TRIGGER IF EXISTS update_discounts_updated_at ON public.discounts;
CREATE TRIGGER update_discounts_updated_at
  BEFORE UPDATE ON public.discounts
  FOR EACH ROW
  EXECUTE PROCEDURE public.handle_updated_at();

ALTER TABLE public.discounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "discounts_select_policy" ON public.discounts;
CREATE POLICY "discounts_select_policy" ON public.discounts
FOR SELECT TO authenticated
USING (
  public.is_business_owner(business_id) OR
  EXISTS (
    SELECT 1
    FROM public.business_members bm
    WHERE bm.business_id = discounts.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
  ) OR
  EXISTS (
    SELECT 1
    FROM public.outlet_members om
    JOIN public.outlets o ON o.id = om.outlet_id
    WHERE o.business_id = discounts.business_id
      AND om.user_id = auth.uid()
      AND om.status = 'active'
  )
);

DROP POLICY IF EXISTS "discounts_manage_policy" ON public.discounts;
CREATE POLICY "discounts_manage_policy" ON public.discounts
FOR ALL TO authenticated
USING (
  public.is_business_owner(business_id) OR
  EXISTS (
    SELECT 1
    FROM public.business_members bm
    WHERE bm.business_id = discounts.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
      AND bm.role IN ('owner', 'admin')
  )
)
WITH CHECK (
  public.is_business_owner(business_id) OR
  EXISTS (
    SELECT 1
    FROM public.business_members bm
    WHERE bm.business_id = discounts.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
      AND bm.role IN ('owner', 'admin')
  )
);
