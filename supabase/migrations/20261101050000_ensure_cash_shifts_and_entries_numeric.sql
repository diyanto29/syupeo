-- ==============================================================================
-- SYUPEO DATABASE MIGRATION SYSTEM
-- Migration: 20261101050000_ensure_cash_shifts_and_entries_numeric.sql
-- Description:
-- Pastikan seluruh kolom moneter di tabel cash_shifts dan cash_flow_entries
-- bertipe NUMERIC / desimal kompatibel agar tidak melempar error Postgres
-- code 22P02: invalid input syntax for type integer: "100000.0".
-- ==============================================================================

-- 1. Tabel cash_shifts
ALTER TABLE IF EXISTS public.cash_shifts 
  ALTER COLUMN starting_cash TYPE NUMERIC USING starting_cash::NUMERIC,
  ALTER COLUMN expected_cash TYPE NUMERIC USING expected_cash::NUMERIC,
  ALTER COLUMN actual_cash TYPE NUMERIC USING actual_cash::NUMERIC,
  ALTER COLUMN difference_amount TYPE NUMERIC USING difference_amount::NUMERIC,
  ALTER COLUMN total_sales_cash TYPE NUMERIC USING total_sales_cash::NUMERIC,
  ALTER COLUMN total_cash_in TYPE NUMERIC USING total_cash_in::NUMERIC,
  ALTER COLUMN total_cash_out TYPE NUMERIC USING total_cash_out::NUMERIC;

-- Kolom alias lama jika ada
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

-- 2. Tabel cash_flow_entries
ALTER TABLE IF EXISTS public.cash_flow_entries 
  ALTER COLUMN amount TYPE NUMERIC USING amount::NUMERIC;

