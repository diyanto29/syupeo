-- ============================================================================
-- Migrasi: Sistem Buku Kasbon & Piutang Pelanggan (Customer Debt / Kasbon System)
-- Tanggal: 2026-10-19
-- ============================================================================

-- 0. Tambahkan tipe 'debt' ke payment_method_type enum jika belum ada
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_method_type') THEN
    BEGIN
      ALTER TYPE public.payment_method_type ADD VALUE IF NOT EXISTS 'debt';
    EXCEPTION
      WHEN duplicate_object THEN null;
    END;
  END IF;
END $$;

-- 1. Tabel Master Pelanggan (Customers)
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    phone VARCHAR(30) NOT NULL,
    address TEXT,
    credit_limit NUMERIC(15,2) NOT NULL DEFAULT 0, -- 0 = Unlimited / Tidak dibatasi
    current_debt NUMERIC(15,2) NOT NULL DEFAULT 0,  -- Total sisa piutang berjalan
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    CONSTRAINT uq_customers_biz_phone UNIQUE (business_id, phone)
);

CREATE INDEX IF NOT EXISTS idx_customers_biz_id ON public.customers(business_id);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON public.customers(business_id, phone);
CREATE INDEX IF NOT EXISTS idx_customers_current_debt ON public.customers(business_id, current_debt DESC);

-- 2. Tabel Buku Kasbon / Piutang Pelanggan (Customer Debts)
CREATE TABLE IF NOT EXISTS public.customer_debts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
    order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
    invoice_number VARCHAR(50),
    total_amount NUMERIC(15,2) NOT NULL CHECK (total_amount > 0),
    remaining_amount NUMERIC(15,2) NOT NULL CHECK (remaining_amount >= 0),
    due_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'unpaid' 
        CHECK (status IN ('unpaid', 'partially_paid', 'paid', 'bad_debt')),
    notes TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_debts_business ON public.customer_debts(business_id);
CREATE INDEX IF NOT EXISTS idx_debts_outlet ON public.customer_debts(outlet_id);
CREATE INDEX IF NOT EXISTS idx_debts_customer ON public.customer_debts(customer_id);
CREATE INDEX IF NOT EXISTS idx_debts_status ON public.customer_debts(business_id, status);
CREATE INDEX IF NOT EXISTS idx_debts_due_date ON public.customer_debts(business_id, due_date);

-- 3. Tabel Riwayat Pembayaran / Cicilan Kasbon (Debt Payments)
CREATE TABLE IF NOT EXISTS public.debt_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    debt_id UUID NOT NULL REFERENCES public.customer_debts(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
    outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
    shift_id UUID REFERENCES public.cash_shifts(id) ON DELETE SET NULL,
    amount_paid NUMERIC(15,2) NOT NULL CHECK (amount_paid > 0),
    payment_method VARCHAR(30) NOT NULL DEFAULT 'cash' 
        CHECK (payment_method IN ('cash', 'transfer', 'qris')),
    notes TEXT,
    received_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_debt_payments_debt ON public.debt_payments(debt_id);
CREATE INDEX IF NOT EXISTS idx_debt_payments_customer ON public.debt_payments(customer_id);
CREATE INDEX IF NOT EXISTS idx_debt_payments_shift ON public.debt_payments(shift_id);

-- 4. Tabel Log Riwayat Pengingat Tagihan WhatsApp (Debt Reminders)
CREATE TABLE IF NOT EXISTS public.debt_reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    debt_id UUID NOT NULL REFERENCES public.customer_debts(id) ON DELETE CASCADE,
    sent_to_phone VARCHAR(30) NOT NULL,
    message_content TEXT NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    sent_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_debt_reminders_debt ON public.debt_reminders(debt_id);

-- 5. Trigger Otomatis: Update current_debt pada Customer saat Kasbon Baru dibuat
CREATE OR REPLACE FUNCTION public.fn_on_customer_debt_inserted()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.customers
    SET current_debt = current_debt + NEW.remaining_amount,
        updated_at = timezone('utc', now())
    WHERE id = NEW.customer_id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_customer_debt_inserted ON public.customer_debts;
CREATE TRIGGER trg_customer_debt_inserted
AFTER INSERT ON public.customer_debts
FOR EACH ROW
EXECUTE FUNCTION public.fn_on_customer_debt_inserted();

-- 6. Trigger Otomatis: Kurangi sisa hutang saat Cicilan / Pelunasan dicatat
CREATE OR REPLACE FUNCTION public.fn_on_debt_payment_inserted()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_remaining NUMERIC(15,2);
    v_status VARCHAR(20);
BEGIN
    -- 1. Update customer_debts
    UPDATE public.customer_debts
    SET remaining_amount = GREATEST(0, remaining_amount - NEW.amount_paid),
        status = CASE 
            WHEN (remaining_amount - NEW.amount_paid) <= 0 THEN 'paid'
            ELSE 'partially_paid'
        END,
        updated_at = timezone('utc', now())
    WHERE id = NEW.debt_id;

    -- 2. Update customers current_debt
    UPDATE public.customers
    SET current_debt = GREATEST(0, current_debt - NEW.amount_paid),
        updated_at = timezone('utc', now())
    WHERE id = NEW.customer_id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_debt_payment_inserted ON public.debt_payments;
CREATE TRIGGER trg_debt_payment_inserted
AFTER INSERT ON public.debt_payments
FOR EACH ROW
EXECUTE FUNCTION public.fn_on_debt_payment_inserted();

-- 7. Row Level Security (RLS)
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_debts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.debt_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.debt_reminders ENABLE ROW LEVEL SECURITY;

-- Policy untuk customers
CREATE POLICY "customers_manage_policy" ON public.customers
FOR ALL TO authenticated
USING (
  public.is_business_owner(business_id)
  OR public.is_business_member(business_id, auth.uid())
)
WITH CHECK (
  public.is_business_owner(business_id)
  OR public.is_business_member(business_id, auth.uid())
);

-- Policy untuk customer_debts
CREATE POLICY "customer_debts_manage_policy" ON public.customer_debts
FOR ALL TO authenticated
USING (
  public.is_business_owner(business_id)
  OR public.is_business_member(business_id, auth.uid())
)
WITH CHECK (
  public.is_business_owner(business_id)
  OR public.is_business_member(business_id, auth.uid())
);

-- Policy untuk debt_payments
CREATE POLICY "debt_payments_manage_policy" ON public.debt_payments
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.customer_debts d
    WHERE d.id = debt_payments.debt_id
      AND (
        public.is_business_owner(d.business_id)
        OR public.is_business_member(d.business_id, auth.uid())
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.customer_debts d
    WHERE d.id = debt_payments.debt_id
      AND (
        public.is_business_owner(d.business_id)
        OR public.is_business_member(d.business_id, auth.uid())
      )
  )
);

-- Policy untuk debt_reminders
CREATE POLICY "debt_reminders_manage_policy" ON public.debt_reminders
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.customer_debts d
    WHERE d.id = debt_reminders.debt_id
      AND (
        public.is_business_owner(d.business_id)
        OR public.is_business_member(d.business_id, auth.uid())
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.customer_debts d
    WHERE d.id = debt_reminders.debt_id
      AND (
        public.is_business_owner(d.business_id)
        OR public.is_business_member(d.business_id, auth.uid())
      )
  )
);
