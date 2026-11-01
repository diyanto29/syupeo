-- Migration: 20261101033000_ensure_menu_items_columns_compatibility.sql
-- Memastikan kolom harga dan stok pada public.menu_items bertipe fleksibel (NUMERIC)
-- untuk mencegah error '22P02: invalid input syntax for type integer' saat konversi audit/stok

DO $$
BEGIN
  -- 1. Pastikan kolom cost_price bertipe NUMERIC
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'menu_items' AND column_name = 'cost_price'
  ) THEN
    ALTER TABLE public.menu_items ALTER COLUMN cost_price TYPE NUMERIC USING cost_price::NUMERIC;
  ELSE
    ALTER TABLE public.menu_items ADD COLUMN cost_price NUMERIC DEFAULT 0;
  END IF;

  -- 2. Pastikan kolom recipe_cost bertipe NUMERIC
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'menu_items' AND column_name = 'recipe_cost'
  ) THEN
    ALTER TABLE public.menu_items ALTER COLUMN recipe_cost TYPE NUMERIC USING recipe_cost::NUMERIC;
  ELSE
    ALTER TABLE public.menu_items ADD COLUMN recipe_cost NUMERIC DEFAULT 0;
  END IF;

  -- 3. Pastikan kolom price bertipe NUMERIC
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'menu_items' AND column_name = 'price'
  ) THEN
    ALTER TABLE public.menu_items ALTER COLUMN price TYPE NUMERIC USING price::NUMERIC;
  ELSE
    ALTER TABLE public.menu_items ADD COLUMN price NUMERIC DEFAULT 0;
  END IF;

  -- 4. Pastikan kolom stock_quantity bertipe NUMERIC(12,2) agar mendukung satuan desimal (kg/liter)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'menu_items' AND column_name = 'stock_quantity'
  ) THEN
    ALTER TABLE public.menu_items ALTER COLUMN stock_quantity TYPE NUMERIC(12,2) USING stock_quantity::NUMERIC(12,2);
  ELSE
    ALTER TABLE public.menu_items ADD COLUMN stock_quantity NUMERIC(12,2) DEFAULT 0;
  END IF;
END $$;

