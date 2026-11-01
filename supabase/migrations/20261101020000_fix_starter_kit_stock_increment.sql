-- Migration: 20261101020000_fix_starter_kit_stock_increment.sql
-- Description: Memperbaiki apply_starter_kit_to_business agar ketika produk sudah ada di etalase toko,
-- kuantitas stoknya DITAMBAHKAN (COALESCE(stock_quantity, 0) + v_item.quantity), bukan menimpa (overwrite).
-- Dan jika produk belum ada, barulah dibuat sebagai produk baru.

CREATE OR REPLACE FUNCTION public.apply_starter_kit_to_business(
  p_business_id UUID,
  p_starter_kit_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_kit_id UUID := p_starter_kit_id;
  v_item RECORD;
  v_cat_name TEXT;
  v_cat_id UUID;
  v_visual_idx INT := 0;
  v_inserted_count INT := 0;
  v_updated_count INT := 0;
BEGIN
  -- 1. Cari starter kit jika belum di-passing
  IF v_kit_id IS NULL THEN
    SELECT starter_kit_id INTO v_kit_id FROM public.businesses WHERE id = p_business_id;
  END IF;

  IF v_kit_id IS NULL THEN
    SELECT id INTO v_kit_id FROM public.retail_starter_kits WHERE is_active = true ORDER BY sort_order LIMIT 1;
  END IF;

  IF v_kit_id IS NULL THEN
    SELECT id INTO v_kit_id FROM public.retail_starter_kits ORDER BY created_at ASC LIMIT 1;
  END IF;

  -- 2. Loop setiap item dari retail_starter_kit_items (dengan fallback master_catalog)
  FOR v_item IN (
    SELECT 
      rski.product_name,
      rski.barcode,
      rski.quantity,
      rski.unit,
      rski.unit_base_price,
      rski.unit_selling_price,
      COALESCE(rski.category, mc.category, 'Sembako') AS category
    FROM public.retail_starter_kit_items rski
    LEFT JOIN public.master_catalog mc ON mc.barcode = rski.barcode OR lower(btrim(mc.name)) = lower(btrim(rski.product_name))
    WHERE rski.starter_kit_id = v_kit_id
  ) LOOP
    v_cat_name := initcap(btrim(v_item.category));
    IF v_cat_name IS NULL OR v_cat_name = '' THEN
      v_cat_name := 'Sembako';
    END IF;

    -- Dapatkan atau buat menu_categories spesifik untuk kategori ini
    SELECT id INTO v_cat_id
    FROM public.menu_categories
    WHERE business_id = p_business_id
      AND lower(btrim(name)) = lower(btrim(v_cat_name))
    LIMIT 1;

    IF v_cat_id IS NULL THEN
      SELECT COALESCE(MAX(visual_index), 0) + 1 INTO v_visual_idx
      FROM public.menu_categories
      WHERE business_id = p_business_id;

      INSERT INTO public.menu_categories (business_id, name, visual_index)
      VALUES (p_business_id, v_cat_name, COALESCE(v_visual_idx, 0))
      RETURNING id INTO v_cat_id;
    END IF;

    -- Masukkan atau perbarui menu_items dengan category_id yang benar
    IF NOT EXISTS (
      SELECT 1 FROM public.menu_items
      WHERE business_id = p_business_id
        AND lower(btrim(name)) = lower(btrim(v_item.product_name))
    ) THEN
      INSERT INTO public.menu_items (
        business_id, category_id, name, price, cost_price, recipe_cost,
        stock_quantity, unit, barcode, stock_available, track_stock_quantity
      ) VALUES (
        p_business_id, v_cat_id, v_item.product_name, v_item.unit_selling_price, v_item.unit_base_price, v_item.unit_base_price,
        v_item.quantity, v_item.unit, v_item.barcode, true, true
      );
      v_inserted_count := v_inserted_count + 1;
    ELSE
      -- Jika produk sudah ada, TAMBAHKAN kuantitas stok fisik yang baru dibeli ke stok yang ada
      UPDATE public.menu_items
      SET 
        category_id = v_cat_id,
        stock_quantity = COALESCE(stock_quantity, 0) + v_item.quantity,
        unit = COALESCE(nullif(unit, ''), v_item.unit),
        barcode = COALESCE(barcode, v_item.barcode),
        stock_available = true,
        track_stock_quantity = true
      WHERE business_id = p_business_id
        AND lower(btrim(name)) = lower(btrim(v_item.product_name));
      v_updated_count := v_updated_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'business_id', p_business_id,
    'starter_kit_id', v_kit_id,
    'items_added', v_inserted_count,
    'items_stock_updated', v_updated_count
  );
END;
$$;

