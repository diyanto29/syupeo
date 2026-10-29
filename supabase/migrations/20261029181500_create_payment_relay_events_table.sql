-- Migration: Create payment_relay_events table for multi-device payment sync
-- Enables Owner device to relay incoming bank/e-wallet payments to Cashier devices reliably.

CREATE TABLE IF NOT EXISTS public.payment_relay_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
    amount NUMERIC(15, 2) NOT NULL,
    app_name TEXT NOT NULL,
    sender TEXT,
    raw_title TEXT,
    raw_content TEXT,
    detected_outlet_name TEXT,
    is_consumed BOOLEAN NOT NULL DEFAULT FALSE,
    consumed_at TIMESTAMPTZ,
    consumed_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Index for instant querying by business, amount, and unconsumed status
CREATE INDEX IF NOT EXISTS idx_payment_relay_events_search 
    ON public.payment_relay_events (business_id, amount, is_consumed, created_at DESC);

-- Enable RLS
ALTER TABLE public.payment_relay_events ENABLE ROW LEVEL SECURITY;

-- Policy: Members of the business can select
CREATE POLICY "Members can view payment relay events of their business"
    ON public.payment_relay_events FOR SELECT
    USING (
        business_id IN (
            SELECT b.id FROM public.businesses b WHERE b.owner_user_id = auth.uid()
            UNION
            SELECT bm.business_id FROM public.business_members bm WHERE bm.user_id = auth.uid()
        )
    );

-- Policy: Members of the business can insert
CREATE POLICY "Members can insert payment relay events to their business"
    ON public.payment_relay_events FOR INSERT
    WITH CHECK (
        business_id IN (
            SELECT b.id FROM public.businesses b WHERE b.owner_user_id = auth.uid()
            UNION
            SELECT bm.business_id FROM public.business_members bm WHERE bm.user_id = auth.uid()
        )
    );

-- Policy: Members of the business can update/consume
CREATE POLICY "Members can update/consume payment relay events of their business"
    ON public.payment_relay_events FOR UPDATE
    USING (
        business_id IN (
            SELECT b.id FROM public.businesses b WHERE b.owner_user_id = auth.uid()
            UNION
            SELECT bm.business_id FROM public.business_members bm WHERE bm.user_id = auth.uid()
        )
    )
    WITH CHECK (
        business_id IN (
            SELECT b.id FROM public.businesses b WHERE b.owner_user_id = auth.uid()
            UNION
            SELECT bm.business_id FROM public.business_members bm WHERE bm.user_id = auth.uid()
        )
    );

-- Enable Realtime for payment_relay_events table
ALTER PUBLICATION supabase_realtime ADD TABLE public.payment_relay_events;
