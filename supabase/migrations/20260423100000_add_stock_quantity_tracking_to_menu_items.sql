-- Separate manual sellability from optional quantity tracking.
-- stock_available stays as the manual "can sell" switch.
-- track_stock_quantity + stock_quantity add optional counted inventory.

ALTER TABLE public.menu_items
ADD COLUMN IF NOT EXISTS track_stock_quantity BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.menu_items
ADD COLUMN IF NOT EXISTS stock_quantity INTEGER NOT NULL DEFAULT 0;

UPDATE public.menu_items
SET stock_quantity = 0
WHERE stock_quantity IS NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'menu_items_stock_quantity_nonnegative'
      AND conrelid = 'public.menu_items'::regclass
  ) THEN
    ALTER TABLE public.menu_items
    ADD CONSTRAINT menu_items_stock_quantity_nonnegative
    CHECK (stock_quantity >= 0);
  END IF;
END $$;

COMMENT ON COLUMN public.menu_items.stock_available IS
  'Manual sellability toggle. False means the item is hidden/unavailable for sale even if stock exists.';

COMMENT ON COLUMN public.menu_items.track_stock_quantity IS
  'When true, stock_quantity is enforced as the counted inventory for this item.';

COMMENT ON COLUMN public.menu_items.stock_quantity IS
  'Current counted stock for items that use quantity tracking.';
