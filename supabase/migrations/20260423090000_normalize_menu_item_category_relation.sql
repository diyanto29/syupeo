-- Normalize menu_items to reference menu_categories by id instead of storing
-- a mutable category name. This keeps renames safe and scopes data to a business.

ALTER TABLE public.menu_categories
ADD COLUMN IF NOT EXISTS business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE public.menu_items
ADD COLUMN IF NOT EXISTS business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE public.menu_items
ADD COLUMN IF NOT EXISTS category_id UUID;

WITH normalized_item_categories AS (
  SELECT DISTINCT
    mi.business_id,
    CASE lower(btrim(mi.category))
      WHEN 'food' THEN 'Makanan'
      WHEN 'drink' THEN 'Minuman'
      WHEN 'dessert' THEN 'Dessert'
      WHEN 'retail' THEN 'Retail/Toko'
      WHEN 'grocery' THEN 'Sembako'
      ELSE nullif(btrim(mi.category), '')
    END AS normalized_name
  FROM public.menu_items mi
  WHERE mi.business_id IS NOT NULL
    AND mi.category IS NOT NULL
),
missing_categories AS (
  SELECT
    nic.business_id,
    nic.normalized_name,
    row_number() OVER (
      PARTITION BY nic.business_id
      ORDER BY nic.normalized_name
    ) - 1 AS visual_offset
  FROM normalized_item_categories nic
  WHERE nic.normalized_name IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM public.menu_categories mc
      WHERE mc.business_id = nic.business_id
        AND lower(btrim(mc.name)) = lower(btrim(nic.normalized_name))
    )
),
current_visual_index AS (
  SELECT
    business_id,
    coalesce(max(visual_index), -1) AS max_visual_index
  FROM public.menu_categories
  WHERE business_id IS NOT NULL
  GROUP BY business_id
)
INSERT INTO public.menu_categories (
  id,
  name,
  visual_index,
  is_visible_in_all_outlets,
  visible_outlet_ids,
  created_at,
  updated_at,
  business_id
)
SELECT
  gen_random_uuid(),
  mc.normalized_name,
  coalesce(cvi.max_visual_index, -1) + mc.visual_offset + 1,
  true,
  '{}'::uuid[],
  now(),
  now(),
  mc.business_id
FROM missing_categories mc
LEFT JOIN current_visual_index cvi
  ON cvi.business_id = mc.business_id;

UPDATE public.menu_items mi
SET category_id = mc.id
FROM public.menu_categories mc
WHERE mi.category_id IS NULL
  AND mi.business_id = mc.business_id
  AND lower(btrim(mc.name)) = lower(
    btrim(
      CASE lower(btrim(mi.category))
        WHEN 'food' THEN 'Makanan'
        WHEN 'drink' THEN 'Minuman'
        WHEN 'dessert' THEN 'Dessert'
        WHEN 'retail' THEN 'Retail/Toko'
        WHEN 'grocery' THEN 'Sembako'
        ELSE coalesce(mi.category, '')
      END
    )
  );

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.menu_categories
    WHERE business_id IS NULL
  ) THEN
    RAISE EXCEPTION
      'menu_categories.business_id masih ada yang NULL. Backfill dulu sebelum enforce NOT NULL.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.menu_items
    WHERE business_id IS NULL
  ) THEN
    RAISE EXCEPTION
      'menu_items.business_id masih ada yang NULL. Backfill dulu sebelum enforce NOT NULL.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.menu_items
    WHERE category_id IS NULL
  ) THEN
    RAISE EXCEPTION
      'Masih ada menu_items yang belum berhasil di-map ke category_id. Periksa data kategori legacy sebelum lanjut.';
  END IF;
END $$;

ALTER TABLE public.menu_categories
ALTER COLUMN business_id SET NOT NULL;

ALTER TABLE public.menu_items
ALTER COLUMN business_id SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'menu_items_category_id_fkey'
      AND conrelid = 'public.menu_items'::regclass
  ) THEN
    ALTER TABLE public.menu_items
    ADD CONSTRAINT menu_items_category_id_fkey
    FOREIGN KEY (category_id)
    REFERENCES public.menu_categories(id)
    ON DELETE RESTRICT;
  END IF;
END $$;

ALTER TABLE public.menu_items
ALTER COLUMN category_id SET NOT NULL;

CREATE INDEX IF NOT EXISTS menu_items_category_id_idx
ON public.menu_items(category_id);

ALTER TABLE public.menu_items
DROP COLUMN IF EXISTS category;
