DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'payment_method_type'
  ) THEN
    CREATE TYPE public.payment_method_type AS ENUM (
      'cash',
      'card',
      'qris',
      'bank_transfer',
      'e_wallet',
      'custom'
    );
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.outlet_payment_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  type public.payment_method_type NOT NULL DEFAULT 'custom',
  provider TEXT,
  account_label TEXT,
  account_number TEXT,
  instructions TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  requires_reference BOOLEAN NOT NULL DEFAULT false,
  allows_change BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT outlet_payment_methods_code_not_blank CHECK (btrim(code) <> ''),
  CONSTRAINT outlet_payment_methods_name_not_blank CHECK (btrim(name) <> ''),
  CONSTRAINT outlet_payment_methods_code_format CHECK (
    code = lower(code) AND
    code ~ '^[a-z0-9][a-z0-9_]{0,62}$'
  )
);

COMMENT ON TABLE public.outlet_payment_methods IS
  'Konfigurasi metode pembayaran per outlet supaya owner multi-outlet bisa mengatur kanal bayar berbeda per cabang.';

COMMENT ON COLUMN public.outlet_payment_methods.outlet_id IS
  'Scope konfigurasi pembayaran. Setiap outlet memiliki daftar metode sendiri.';

COMMENT ON COLUMN public.outlet_payment_methods.requires_reference IS
  'Jika true, kasir perlu mengisi nomor referensi/approval saat metode ini dipakai.';

COMMENT ON COLUMN public.outlet_payment_methods.allows_change IS
  'Jika true, metode dapat menghasilkan kembalian, umumnya hanya cash.';

CREATE INDEX IF NOT EXISTS outlet_payment_methods_outlet_id_idx
ON public.outlet_payment_methods (outlet_id);

CREATE INDEX IF NOT EXISTS outlet_payment_methods_active_idx
ON public.outlet_payment_methods (outlet_id, is_active, sort_order);

CREATE UNIQUE INDEX IF NOT EXISTS outlet_payment_methods_outlet_code_unique_idx
ON public.outlet_payment_methods (outlet_id, code);

DROP TRIGGER IF EXISTS set_outlet_payment_methods_updated_at
ON public.outlet_payment_methods;
CREATE TRIGGER set_outlet_payment_methods_updated_at
  BEFORE UPDATE ON public.outlet_payment_methods
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.seed_default_outlet_payment_methods(
  target_outlet_id UUID
)
RETURNS VOID
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
  INSERT INTO public.outlet_payment_methods (
    outlet_id,
    code,
    name,
    type,
    provider,
    is_active,
    sort_order,
    requires_reference,
    allows_change
  )
  VALUES
    (
      target_outlet_id,
      'cash',
      'Cash',
      'cash',
      NULL,
      true,
      0,
      false,
      true
    ),
    (
      target_outlet_id,
      'debit_credit',
      'Debit/Credit',
      'card',
      NULL,
      true,
      10,
      true,
      false
    ),
    (
      target_outlet_id,
      'qris',
      'QRIS',
      'qris',
      'QRIS',
      true,
      20,
      true,
      false
    )
  ON CONFLICT (outlet_id, code) DO NOTHING;
$$;

CREATE OR REPLACE FUNCTION public.handle_outlet_payment_methods_seed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.seed_default_outlet_payment_methods(NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS seed_outlet_payment_methods_after_insert
ON public.outlets;
CREATE TRIGGER seed_outlet_payment_methods_after_insert
  AFTER INSERT ON public.outlets
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_outlet_payment_methods_seed();

SELECT public.seed_default_outlet_payment_methods(id)
FROM public.outlets;

ALTER TABLE public.outlet_payment_methods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "outlet_payment_methods_select_related"
ON public.outlet_payment_methods;
CREATE POLICY "outlet_payment_methods_select_related"
ON public.outlet_payment_methods
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.outlets o
    WHERE o.id = outlet_payment_methods.outlet_id
      AND (
        public.is_business_owner(o.business_id)
        OR public.is_business_member(o.business_id, auth.uid())
        OR EXISTS (
          SELECT 1
          FROM public.outlet_members om
          WHERE om.outlet_id = o.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
        )
      )
  )
);

DROP POLICY IF EXISTS "outlet_payment_methods_manage_owner_admin"
ON public.outlet_payment_methods;
CREATE POLICY "outlet_payment_methods_manage_owner_admin"
ON public.outlet_payment_methods
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.outlets o
    WHERE o.id = outlet_payment_methods.outlet_id
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
    WHERE o.id = outlet_payment_methods.outlet_id
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
