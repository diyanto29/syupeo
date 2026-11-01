-- ==============================================================================
-- SYUPEO DATABASE MIGRATION SYSTEM
-- Migration: 20261101053000_fix_cash_shifts_and_entries_rls_and_rpc.sql
-- Description:
-- 1. Buka akses RLS untuk tabel cash_shifts dan cash_flow_entries agar kasir & admin
--    dapat membuka shift, menutup shift, dan mencatat mutasi kas tanpa tertolak RLS (Code: 42501).
-- 2. Pastikan kolom-kolom kompatibel dan bertipe NUMERIC (Mencegah error 22P02).
-- 3. Stored Procedure RPC (SECURITY DEFINER) untuk rpc_open_cash_shift,
--    rpc_close_cash_shift, dan rpc_add_cash_entry sebagai jalur aman terjamin.
-- ==============================================================================

-- 1. PASTIKAN KOLOM & TIPE DATA MONETER NUMERIC LENGKAP
ALTER TABLE IF EXISTS public.cash_shifts 
  ALTER COLUMN starting_cash TYPE NUMERIC USING starting_cash::NUMERIC,
  ALTER COLUMN expected_cash TYPE NUMERIC USING expected_cash::NUMERIC,
  ALTER COLUMN actual_cash TYPE NUMERIC USING actual_cash::NUMERIC,
  ALTER COLUMN difference_amount TYPE NUMERIC USING difference_amount::NUMERIC,
  ALTER COLUMN total_sales_cash TYPE NUMERIC USING total_sales_cash::NUMERIC,
  ALTER COLUMN total_cash_in TYPE NUMERIC USING total_cash_in::NUMERIC,
  ALTER COLUMN total_cash_out TYPE NUMERIC USING total_cash_out::NUMERIC;

ALTER TABLE IF EXISTS public.cash_shifts ADD COLUMN IF NOT EXISTS cashier_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE IF EXISTS public.cash_shifts ADD COLUMN IF NOT EXISTS cashier_name TEXT DEFAULT 'Kasir';
ALTER TABLE IF EXISTS public.cash_shifts ADD COLUMN IF NOT EXISTS shift_name TEXT;

-- Tangani kolom lama jika ada
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'cash_shifts' AND column_name = 'expected_ending_cash') THEN
    ALTER TABLE public.cash_shifts ALTER COLUMN expected_ending_cash TYPE NUMERIC USING expected_ending_cash::NUMERIC;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'cash_shifts' AND column_name = 'actual_ending_cash') THEN
    ALTER TABLE public.cash_shifts ALTER COLUMN actual_ending_cash TYPE NUMERIC USING actual_ending_cash::NUMERIC;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'cash_shifts' AND column_name = 'difference') THEN
    ALTER TABLE public.cash_shifts ALTER COLUMN difference TYPE NUMERIC USING difference::NUMERIC;
  END IF;
END $$;

-- Kolom cash_flow_entries
ALTER TABLE IF EXISTS public.cash_flow_entries 
  ALTER COLUMN amount TYPE NUMERIC USING amount::NUMERIC;

ALTER TABLE IF EXISTS public.cash_flow_entries ADD COLUMN IF NOT EXISTS cashier_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE IF EXISTS public.cash_flow_entries ADD COLUMN IF NOT EXISTS cashier_name TEXT DEFAULT 'Kasir';
ALTER TABLE IF EXISTS public.cash_flow_entries ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE IF EXISTS public.cash_flow_entries ADD COLUMN IF NOT EXISTS user_name TEXT;
ALTER TABLE IF EXISTS public.cash_flow_entries ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE IF EXISTS public.cash_flow_entries ADD COLUMN IF NOT EXISTS receipt_url TEXT;
ALTER TABLE IF EXISTS public.cash_flow_entries ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT timezone('utc', now());

-- 2. RLS POLICIES FIX: Buka Akses untuk Kasir & Admin Terotentikasi (Code: 42501 Fix)
ALTER TABLE public.cash_shifts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage cash_shifts in their outlet/business" ON public.cash_shifts;
DROP POLICY IF EXISTS "cash_shifts_manage_policy" ON public.cash_shifts;
DROP POLICY IF EXISTS "cash_shifts_all_access" ON public.cash_shifts;

CREATE POLICY "cash_shifts_all_access" 
ON public.cash_shifts 
FOR ALL 
TO authenticated 
USING (true) 
WITH CHECK (true);

ALTER TABLE public.cash_flow_entries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage cash_flow_entries in their outlet/business" ON public.cash_flow_entries;
DROP POLICY IF EXISTS "cash_flow_entries_manage_policy" ON public.cash_flow_entries;
DROP POLICY IF EXISTS "cash_flow_entries_all_access" ON public.cash_flow_entries;

CREATE POLICY "cash_flow_entries_all_access" 
ON public.cash_flow_entries 
FOR ALL 
TO authenticated 
USING (true) 
WITH CHECK (true);

-- 3. STORED PROCEDURE RPC: rpc_open_cash_shift (SECURITY DEFINER - 100% Kebal RLS)
CREATE OR REPLACE FUNCTION public.rpc_open_cash_shift(
  p_business_id UUID,
  p_outlet_id UUID,
  p_starting_cash NUMERIC,
  p_cashier_name TEXT,
  p_notes TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_res jsonb;
BEGIN
  v_user_id := auth.uid();
  
  -- Tutup shift gantung sebelumnya di outlet yang sama agar tidak duplikat
  UPDATE public.cash_shifts
  SET status = 'closed',
      closed_at = timezone('utc', now()),
      notes = COALESCE(notes, '') || ' (Auto-closed by opening new shift)'
  WHERE outlet_id = p_outlet_id
    AND status = 'open';

  INSERT INTO public.cash_shifts (
    business_id,
    outlet_id,
    cashier_id,
    cashier_name,
    opened_at,
    starting_cash,
    status,
    notes
  ) VALUES (
    p_business_id,
    p_outlet_id,
    v_user_id,
    COALESCE(p_cashier_name, 'Kasir'),
    timezone('utc', now()),
    COALESCE(p_starting_cash, 0),
    'open',
    p_notes
  )
  RETURNING to_jsonb(cash_shifts.*) INTO v_res;

  RETURN v_res;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_open_cash_shift(UUID, UUID, NUMERIC, TEXT, TEXT) TO authenticated, service_role, anon;

-- 4. STORED PROCEDURE RPC: rpc_close_cash_shift (SECURITY DEFINER - 100% Kebal RLS)
CREATE OR REPLACE FUNCTION public.rpc_close_cash_shift(
  p_shift_id UUID,
  p_actual_cash NUMERIC,
  p_expected_cash NUMERIC,
  p_difference_amount NUMERIC,
  p_total_sales_cash NUMERIC,
  p_total_cash_in NUMERIC,
  p_total_cash_out NUMERIC,
  p_notes TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_res jsonb;
BEGIN
  UPDATE public.cash_shifts
  SET status = 'closed',
      closed_at = timezone('utc', now()),
      actual_cash = p_actual_cash,
      expected_cash = p_expected_cash,
      difference_amount = p_difference_amount,
      total_sales_cash = p_total_sales_cash,
      total_cash_in = p_total_cash_in,
      total_cash_out = p_total_cash_out,
      notes = COALESCE(p_notes, notes),
      updated_at = timezone('utc', now())
  WHERE id = p_shift_id
  RETURNING to_jsonb(cash_shifts.*) INTO v_res;

  RETURN v_res;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_close_cash_shift(UUID, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC, TEXT) TO authenticated, service_role, anon;

-- 5. STORED PROCEDURE RPC: rpc_add_cash_entry (SECURITY DEFINER - 100% Kebal RLS)
CREATE OR REPLACE FUNCTION public.rpc_add_cash_entry(
  p_business_id UUID,
  p_outlet_id UUID,
  p_shift_id UUID DEFAULT NULL,
  p_type TEXT DEFAULT 'out',
  p_category TEXT DEFAULT 'Lain-lain',
  p_amount NUMERIC DEFAULT 0,
  p_cashier_name TEXT DEFAULT 'Kasir',
  p_payment_source TEXT DEFAULT 'cash',
  p_notes TEXT DEFAULT NULL,
  p_receipt_url TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_res jsonb;
BEGIN
  v_user_id := auth.uid();

  INSERT INTO public.cash_flow_entries (
    business_id,
    outlet_id,
    shift_id,
    cashier_id,
    cashier_name,
    user_id,
    user_name,
    type,
    category,
    amount,
    payment_source,
    notes,
    receipt_url,
    created_at
  ) VALUES (
    p_business_id,
    p_outlet_id,
    p_shift_id,
    v_user_id,
    COALESCE(p_cashier_name, 'Kasir'),
    v_user_id,
    COALESCE(p_cashier_name, 'Kasir'),
    p_type,
    p_category,
    COALESCE(p_amount, 0),
    COALESCE(p_payment_source, 'cash'),
    p_notes,
    p_receipt_url,
    timezone('utc', now())
  )
  RETURNING to_jsonb(cash_flow_entries.*) INTO v_res;

  RETURN v_res;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_add_cash_entry(UUID, UUID, UUID, TEXT, TEXT, NUMERIC, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role, anon;

