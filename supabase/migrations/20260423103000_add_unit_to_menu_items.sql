-- Add a flexible sales unit for menu items.
-- Keep this as free text so retail, cafe, and restaurant businesses can use
-- their own labels such as pcs, botol, cup, porsi, slice, bowl, or set.

ALTER TABLE public.menu_items
ADD COLUMN IF NOT EXISTS unit TEXT DEFAULT 'pcs';

UPDATE public.menu_items
SET unit = 'pcs'
WHERE unit IS NULL OR btrim(unit) = '';

COMMENT ON COLUMN public.menu_items.unit IS
  'Sales unit label for this item, e.g. pcs, cup, porsi, slice, bottle, or set.';
