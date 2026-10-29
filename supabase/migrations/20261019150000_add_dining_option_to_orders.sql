-- Add dining_option column to orders table
-- Supports: 'dine_in' (makan di tempat), 'take_away' (bungkus / bawa pulang), 'delivery' (pesan antar)

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS dining_option TEXT DEFAULT 'dine_in';

COMMENT ON COLUMN public.orders.dining_option IS 'Tipe konsumsi: dine_in (makan di tempat), take_away (bungkus), delivery (antar)';

-- Auto-fill dining_option for historical orders based on notes
UPDATE public.orders
SET dining_option = 'take_away'
WHERE dining_option IS NULL AND notes ILIKE '%[TAKEAWAY]%';

UPDATE public.orders
SET dining_option = 'delivery'
WHERE dining_option IS NULL AND notes ILIKE '%[DELIVERY]%';

UPDATE public.orders
SET dining_option = 'dine_in'
WHERE dining_option IS NULL;
