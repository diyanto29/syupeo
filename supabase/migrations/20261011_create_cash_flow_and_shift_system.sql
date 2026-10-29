-- ============================================================================
-- Migrasi: Sistem Arus Kas & Manajemen Shift Kasir (Cash Flow & Shift System)
-- ============================================================================

-- 1. Tabel Shift Kasir (Buka/Tutup Kasir & Rekonsiliasi Kas Laci)
CREATE TABLE IF NOT EXISTS public.cash_shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE,
  outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
  cashier_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  cashier_name TEXT NOT NULL,
  opened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at TIMESTAMPTZ,
  starting_cash NUMERIC(15,2) NOT NULL DEFAULT 0,
  expected_cash NUMERIC(15,2),
  actual_cash NUMERIC(15,2),
  difference_amount NUMERIC(15,2),
  total_sales_cash NUMERIC(15,2) NOT NULL DEFAULT 0,
  total_cash_in NUMERIC(15,2) NOT NULL DEFAULT 0,
  total_cash_out NUMERIC(15,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Tabel Mutasi Arus Kas (Kas Masuk & Kas Keluar Operasional)
CREATE TABLE IF NOT EXISTS public.cash_flow_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE,
  outlet_id UUID REFERENCES public.outlets(id) ON DELETE CASCADE,
  shift_id UUID REFERENCES public.cash_shifts(id) ON DELETE SET NULL,
  cashier_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  cashier_name TEXT,
  type TEXT NOT NULL CHECK (type IN ('in', 'out')),
  category TEXT NOT NULL,
  amount NUMERIC(15,2) NOT NULL CHECK (amount > 0),
  payment_source TEXT NOT NULL DEFAULT 'cash' CHECK (payment_source IN ('cash', 'bank_transfer', 'other')),
  notes TEXT,
  receipt_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Indexes untuk Performa Kueri Real-time
CREATE INDEX IF NOT EXISTS idx_cash_shifts_outlet_status ON public.cash_shifts(outlet_id, status);
CREATE INDEX IF NOT EXISTS idx_cash_shifts_opened_at ON public.cash_shifts(opened_at DESC);
CREATE INDEX IF NOT EXISTS idx_cash_flow_outlet_date ON public.cash_flow_entries(outlet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cash_flow_shift_id ON public.cash_flow_entries(shift_id);

-- 4. Aktifkan Row Level Security (RLS)
ALTER TABLE public.cash_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_flow_entries ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies untuk cash_shifts
DROP POLICY IF EXISTS "Users can manage cash_shifts in their outlet/business" ON public.cash_shifts;
DROP POLICY IF EXISTS "cash_shifts_manage_policy" ON public.cash_shifts;

CREATE POLICY "cash_shifts_manage_policy"
ON public.cash_shifts
FOR ALL
TO authenticated
USING (
  -- Owner bisnis (menggunakan helper function resmi proyek)
  public.is_business_owner(business_id)
  -- Member bisnis (owner, admin, cashier)
  OR EXISTS (
    SELECT 1 FROM public.business_members bm
    WHERE bm.business_id = cash_shifts.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
      AND bm.role IN ('owner', 'admin', 'cashier')
  )
  -- Member outlet (owner, admin, cashier)
  OR EXISTS (
    SELECT 1 FROM public.outlet_members om
    WHERE om.outlet_id = cash_shifts.outlet_id
      AND om.user_id = auth.uid()
      AND om.status = 'active'
      AND om.role IN ('owner', 'admin', 'cashier')
  )
  -- Super Admin
  OR EXISTS (
    SELECT 1 FROM public.admin_users au
    WHERE au.email = (auth.jwt() ->> 'email')
      AND au.is_active = true
  )
)
WITH CHECK (
  public.is_business_owner(business_id)
  OR EXISTS (
    SELECT 1 FROM public.business_members bm
    WHERE bm.business_id = cash_shifts.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
      AND bm.role IN ('owner', 'admin', 'cashier')
  )
  OR EXISTS (
    SELECT 1 FROM public.outlet_members om
    WHERE om.outlet_id = cash_shifts.outlet_id
      AND om.user_id = auth.uid()
      AND om.status = 'active'
      AND om.role IN ('owner', 'admin', 'cashier')
  )
  OR EXISTS (
    SELECT 1 FROM public.admin_users au
    WHERE au.email = (auth.jwt() ->> 'email')
      AND au.is_active = true
  )
);

-- 6. RLS Policies untuk cash_flow_entries
DROP POLICY IF EXISTS "Users can manage cash_flow_entries in their outlet/business" ON public.cash_flow_entries;
DROP POLICY IF EXISTS "cash_flow_entries_manage_policy" ON public.cash_flow_entries;

CREATE POLICY "cash_flow_entries_manage_policy"
ON public.cash_flow_entries
FOR ALL
TO authenticated
USING (
  public.is_business_owner(business_id)
  OR EXISTS (
    SELECT 1 FROM public.business_members bm
    WHERE bm.business_id = cash_flow_entries.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
      AND bm.role IN ('owner', 'admin', 'cashier')
  )
  OR EXISTS (
    SELECT 1 FROM public.outlet_members om
    WHERE om.outlet_id = cash_flow_entries.outlet_id
      AND om.user_id = auth.uid()
      AND om.status = 'active'
      AND om.role IN ('owner', 'admin', 'cashier')
  )
  OR EXISTS (
    SELECT 1 FROM public.admin_users au
    WHERE au.email = (auth.jwt() ->> 'email')
      AND au.is_active = true
  )
)
WITH CHECK (
  public.is_business_owner(business_id)
  OR EXISTS (
    SELECT 1 FROM public.business_members bm
    WHERE bm.business_id = cash_flow_entries.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
      AND bm.role IN ('owner', 'admin', 'cashier')
  )
  OR EXISTS (
    SELECT 1 FROM public.outlet_members om
    WHERE om.outlet_id = cash_flow_entries.outlet_id
      AND om.user_id = auth.uid()
      AND om.status = 'active'
      AND om.role IN ('owner', 'admin', 'cashier')
  )
  OR EXISTS (
    SELECT 1 FROM public.admin_users au
    WHERE au.email = (auth.jwt() ->> 'email')
      AND au.is_active = true
  )
);

-- 7. Grant Hak Akses
GRANT ALL ON public.cash_shifts TO authenticated;
GRANT ALL ON public.cash_flow_entries TO authenticated;
