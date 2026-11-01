-- Migrasi Penyelaras Skema Tabel order_payments untuk Offline Sync Kasir & Multi-Payment
-- Memastikan kolom payment_method, payment_method_id, method_name, method_type tersedia dengan aman

DO $$
BEGIN
  -- 1. Kolom legacy payment_method jika belum ada
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'order_payments' AND column_name = 'payment_method'
  ) THEN
    ALTER TABLE public.order_payments ADD COLUMN payment_method TEXT DEFAULT 'Tunai';
  ELSE
    ALTER TABLE public.order_payments ALTER COLUMN payment_method DROP NOT NULL;
    ALTER TABLE public.order_payments ALTER COLUMN payment_method SET DEFAULT 'Tunai';
  END IF;

  -- 2. Kolom payment_method_id
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'order_payments' AND column_name = 'payment_method_id'
  ) THEN
    ALTER TABLE public.order_payments ADD COLUMN payment_method_id UUID;
  END IF;

  -- 3. Kolom method_name & method_type
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'order_payments' AND column_name = 'method_name'
  ) THEN
    ALTER TABLE public.order_payments ADD COLUMN method_name TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'order_payments' AND column_name = 'method_type'
  ) THEN
    ALTER TABLE public.order_payments ADD COLUMN method_type TEXT DEFAULT 'cash';
  END IF;

  -- 4. Kolom reference_number
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'order_payments' AND column_name = 'reference_number'
  ) THEN
    ALTER TABLE public.order_payments ADD COLUMN reference_number TEXT;
  END IF;
END $$;

-- Reload Schema Cache PostgREST
NOTIFY pgrst, 'reload schema';

