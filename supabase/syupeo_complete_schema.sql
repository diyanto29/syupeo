-- ====================================================================
-- SYUPEO - COMPLETE INITIAL SCHEMA (FROM SCRATCH / DARI NOL)
-- Target Project: https://fgzmwmtssrviptflsjqy.supabase.co
-- Standalone execution in Supabase SQL Editor
-- ====================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. ENUMS & CUSTOM TYPES
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'app_role') THEN
    CREATE TYPE public.app_role AS ENUM ('owner', 'admin', 'cashier', 'waiter', 'kitchen', 'customer');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'membership_status') THEN
    CREATE TYPE public.membership_status AS ENUM ('active', 'invited', 'disabled');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'lead_status') THEN
    CREATE TYPE public.lead_status AS ENUM ('new', 'contacted', 'demo', 'quoted', 'won', 'lost');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'restock_order_status') THEN
    CREATE TYPE public.restock_order_status AS ENUM ('draft', 'submitted', 'approved', 'packing', 'shipping', 'delivered', 'cancelled');
  END IF;
END $$;

-- 3. PROFILES (Tied to Supabase Auth)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  email TEXT,
  full_name TEXT,
  phone TEXT,
  avatar_url TEXT,
  role public.app_role NOT NULL DEFAULT 'owner',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4. BUSINESS TYPE TEMPLATES & SUBSCRIPTION PLANS
CREATE TABLE IF NOT EXISTS public.business_type_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  code TEXT UNIQUE NOT NULL,
  description TEXT,
  icon_name TEXT,
  default_enabled_features TEXT[] DEFAULT '{}',
  features_config JSONB DEFAULT '{}',
  limits_config JSONB DEFAULT '{}',
  role_labels JSONB DEFAULT '{}',
  max_transactions INT DEFAULT 1000,
  max_products INT DEFAULT 100,
  max_outlets INT DEFAULT 1,
  show_ads BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.subscription_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  code TEXT UNIQUE NOT NULL,
  max_transactions_month INT NOT NULL DEFAULT 500,
  max_products INT NOT NULL DEFAULT 100,
  max_outlets INT NOT NULL DEFAULT 1,
  price_monthly INT NOT NULL DEFAULT 0,
  pricing_tiers JSONB DEFAULT '{}',
  features JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 5. PARTNERS & AFFILIATES
CREATE TABLE IF NOT EXISTS public.partners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT UNIQUE,
  referral_code TEXT UNIQUE,
  commission_rate NUMERIC(5, 2) NOT NULL DEFAULT 20.0,
  bank_name TEXT,
  bank_account_number TEXT,
  bank_account_holder TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.partner_payouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID NOT NULL REFERENCES public.partners(id) ON DELETE CASCADE,
  amount INT NOT NULL,
  bank_name TEXT,
  bank_account_number TEXT,
  bank_account_holder TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  reference_note TEXT,
  proof_url TEXT,
  processed_by TEXT,
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 6. ADMIN USERS (Super Admin & Admin Panel)
CREATE TABLE IF NOT EXISTS public.admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  role TEXT NOT NULL DEFAULT 'admin', -- 'super_admin', 'admin', 'partner'
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  can_manage_licenses BOOLEAN NOT NULL DEFAULT FALSE,
  partner_id UUID REFERENCES public.partners(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 7. BUSINESSES (Mitra Toko Retail)
CREATE TABLE IF NOT EXISTS public.businesses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE,
  business_type TEXT DEFAULT 'retail',
  owner_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'active',
  phone TEXT,
  email TEXT,
  address TEXT,
  plan_id UUID REFERENCES public.subscription_plans(id),
  subscription_status TEXT DEFAULT 'active',
  subscription_end_at TIMESTAMPTZ,
  max_transactions INT DEFAULT 1000,
  max_products INT DEFAULT 100,
  max_outlets INT DEFAULT 1,
  show_ads BOOLEAN DEFAULT FALSE,
  enabled_features TEXT[] DEFAULT '{}',
  features_config JSONB DEFAULT '{}',
  limits_config JSONB DEFAULT '{}',
  role_labels JSONB DEFAULT '{}',
  referred_by_partner_id UUID REFERENCES public.partners(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 8. BUSINESS MEMBERS (Kasir, Staf, Manajer)
CREATE TABLE IF NOT EXISTS public.business_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL DEFAULT 'cashier',
  status public.membership_status NOT NULL DEFAULT 'active',
  invited_email TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(business_id, user_id)
);

-- 9. OUTLETS (Cabang Toko Fisik)
CREATE TABLE IF NOT EXISTS public.outlets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  code TEXT,
  phone TEXT,
  address TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.outlet_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'cashier',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(outlet_id, user_id)
);

-- 10. CATEGORIES & MENU CATEGORIES
CREATE TABLE IF NOT EXISTS public.categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  icon TEXT,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.menu_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  icon TEXT,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 11. PRODUCTS & MENU ITEMS
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  price INT NOT NULL DEFAULT 0,
  cost_price INT DEFAULT 0,
  barcode TEXT,
  sku TEXT,
  image_url TEXT,
  unit TEXT DEFAULT 'Pcs',
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  stock_quantity INT DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.menu_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  category_id UUID REFERENCES public.menu_categories(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  price INT NOT NULL DEFAULT 0,
  cost_price INT DEFAULT 0,
  recipe_cost INT DEFAULT 0,
  sku TEXT,
  barcode TEXT,
  image_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  stock_available BOOLEAN NOT NULL DEFAULT TRUE,
  track_stock_quantity BOOLEAN NOT NULL DEFAULT FALSE,
  stock_quantity INT DEFAULT 0,
  unit TEXT DEFAULT 'Pcs',
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.menu_item_variants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_item_id UUID NOT NULL REFERENCES public.menu_items(id) ON DELETE CASCADE,
  business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  price INT NOT NULL DEFAULT 0,
  sku TEXT,
  barcode TEXT,
  stock_available BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.menu_item_tiered_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_item_id UUID NOT NULL REFERENCES public.menu_items(id) ON DELETE CASCADE,
  business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE,
  min_quantity INT NOT NULL DEFAULT 2,
  price INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 12. INVENTORY & INGREDIENTS
CREATE TABLE IF NOT EXISTS public.inventory_ingredients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  outlet_id UUID REFERENCES public.outlets(id) ON DELETE SET NULL,
  sku TEXT,
  name TEXT NOT NULL,
  category TEXT,
  base_unit TEXT NOT NULL DEFAULT 'Gram',
  purchase_unit TEXT,
  conversion_ratio NUMERIC(10, 2) DEFAULT 1.0,
  current_stock NUMERIC(12, 2) NOT NULL DEFAULT 0,
  min_stock_alert NUMERIC(12, 2) NOT NULL DEFAULT 10,
  cost_per_base_unit INT NOT NULL DEFAULT 0,
  storage_type TEXT DEFAULT 'dry',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.ingredient_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ingredient_id UUID NOT NULL REFERENCES public.inventory_ingredients(id) ON DELETE CASCADE,
  movement_type TEXT NOT NULL, -- 'in', 'out', 'adjustment'
  quantity NUMERIC(12, 2) NOT NULL,
  cost_per_unit INT DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.menu_item_recipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_item_id UUID NOT NULL REFERENCES public.menu_items(id) ON DELETE CASCADE,
  ingredient_id UUID NOT NULL REFERENCES public.inventory_ingredients(id) ON DELETE CASCADE,
  amount_needed NUMERIC(10, 2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.stock_opname_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  session_date DATE NOT NULL DEFAULT CURRENT_DATE,
  status TEXT NOT NULL DEFAULT 'draft', -- 'draft', 'finalized'
  notes TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.stock_opname_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.stock_opname_sessions(id) ON DELETE CASCADE,
  ingredient_id UUID NOT NULL REFERENCES public.inventory_ingredients(id) ON DELETE CASCADE,
  system_stock NUMERIC(12, 2) NOT NULL,
  actual_stock NUMERIC(12, 2) NOT NULL,
  difference NUMERIC(12, 2) NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 13. ORDERS & CASHIER TRANSACTIONS
CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  invoice_number TEXT NOT NULL,
  customer_name TEXT,
  customer_phone TEXT,
  table_number INT,
  status TEXT NOT NULL DEFAULT 'paid', -- 'draft', 'confirmed', 'paid', 'void', 'refunded'
  notes TEXT,
  void_reason TEXT,
  subtotal INT NOT NULL DEFAULT 0,
  discount_total INT NOT NULL DEFAULT 0,
  tax_amount INT NOT NULL DEFAULT 0,
  grand_total INT NOT NULL DEFAULT 0,
  total_amount INT NOT NULL DEFAULT 0,
  paid_amount INT NOT NULL DEFAULT 0,
  change_amount INT NOT NULL DEFAULT 0,
  payment_method TEXT DEFAULT 'cash',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  paid_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  menu_item_id UUID REFERENCES public.menu_items(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  unit_price INT NOT NULL DEFAULT 0,
  price INT NOT NULL DEFAULT 0,
  quantity INT NOT NULL DEFAULT 1,
  subtotal INT NOT NULL DEFAULT 0,
  cost_price INT DEFAULT 0,
  variant_name TEXT,
  discount_applied INT DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.order_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  method_name TEXT NOT NULL DEFAULT 'Tunai',
  method_type TEXT NOT NULL DEFAULT 'cash',
  amount INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.sales_returns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  refund_amount INT NOT NULL DEFAULT 0,
  return_type TEXT NOT NULL DEFAULT 'refund_cash',
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 14. CASH SHIFTS & CASH FLOW ENTRIES
CREATE TABLE IF NOT EXISTS public.cash_shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  cashier_id UUID REFERENCES auth.users(id),
  cashier_name TEXT,
  shift_name TEXT,
  starting_cash INT NOT NULL DEFAULT 0,
  expected_cash INT,
  expected_ending_cash INT,
  actual_cash INT,
  actual_ending_cash INT,
  difference_amount INT DEFAULT 0,
  difference INT DEFAULT 0,
  total_sales_cash INT DEFAULT 0,
  total_cash_in INT DEFAULT 0,
  total_cash_out INT DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'open', -- 'open', 'closed'
  notes TEXT,
  opened_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  closed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.cash_flow_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  shift_id UUID REFERENCES public.cash_shifts(id) ON DELETE SET NULL,
  user_id UUID NOT NULL,
  user_name TEXT,
  type TEXT NOT NULL, -- 'in', 'out'
  category TEXT NOT NULL,
  amount INT NOT NULL,
  payment_source TEXT DEFAULT 'cash_drawer',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 15. CUSTOMERS & DEBTS (Kasbon / Hutang Pelanggan)
CREATE TABLE IF NOT EXISTS public.customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  address TEXT,
  credit_limit INT NOT NULL DEFAULT 500000,
  current_debt INT NOT NULL DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.customer_debts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
  invoice_number TEXT,
  total_amount INT NOT NULL,
  remaining_amount INT NOT NULL,
  due_date DATE,
  status TEXT NOT NULL DEFAULT 'unpaid', -- 'unpaid', 'partially_paid', 'paid', 'bad_debt'
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.debt_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  debt_id UUID NOT NULL REFERENCES public.customer_debts(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  amount_paid INT NOT NULL,
  payment_method TEXT NOT NULL DEFAULT 'cash',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 16. DISCOUNTS & PROMOS
CREATE TABLE IF NOT EXISTS public.discounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  code TEXT,
  description TEXT,
  type TEXT NOT NULL DEFAULT 'percentage', -- 'percentage', 'fixed_amount'
  percentage_value NUMERIC(5, 2),
  amount_value INT,
  max_discount_amount INT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 17. STAFF INVITATIONS
CREATE TABLE IF NOT EXISTS public.staff_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'cashier',
  token TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'accepted', 'expired'
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 18. RETAIL STARTER KITS (Paket Usaha Retail & Produk Perdana)
CREATE TABLE IF NOT EXISTS public.retail_starter_kits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE,
  badge TEXT,
  price INT NOT NULL DEFAULT 0,
  original_price INT,
  description TEXT,
  suitable_for TEXT,
  items_included JSONB NOT NULL DEFAULT '[]',
  is_popular BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Bersihkan objek lama hardware_packages secara aman (Cek tipe: TABLE vs VIEW)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_views WHERE schemaname = 'public' AND viewname = 'hardware_packages') THEN
    EXECUTE 'DROP VIEW public.hardware_packages CASCADE';
  ELSIF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'hardware_packages') THEN
    EXECUTE 'DROP TABLE public.hardware_packages CASCADE';
  END IF;
END $$;

-- Backward compatibility view
CREATE OR REPLACE VIEW public.hardware_packages AS
SELECT * FROM public.retail_starter_kits;

-- 19. SUBSCRIPTION HISTORIES & COMMISSIONS
CREATE TABLE IF NOT EXISTS public.subscription_histories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  plan_id UUID REFERENCES public.subscription_plans(id),
  action_type TEXT NOT NULL DEFAULT 'new', -- 'trial', 'new', 'renewal', 'upgrade', 'manual_admin'
  duration_type TEXT NOT NULL DEFAULT 'months', -- 'days', 'months', 'lifetime'
  duration_value INT NOT NULL DEFAULT 1,
  price_paid INT NOT NULL DEFAULT 0,
  started_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  ended_at TIMESTAMPTZ,
  partner_id UUID REFERENCES public.partners(id),
  commission_rate NUMERIC(5, 2) NOT NULL DEFAULT 0,
  commission_amount INT NOT NULL DEFAULT 0,
  payment_status TEXT NOT NULL DEFAULT 'paid', -- 'paid', 'free_trial', 'waived'
  payment_method TEXT,
  notes TEXT,
  created_by_admin TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.partner_commissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID NOT NULL REFERENCES public.partners(id) ON DELETE CASCADE,
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  subscription_history_id UUID REFERENCES public.subscription_histories(id),
  subscription_amount INT NOT NULL DEFAULT 0,
  commission_rate NUMERIC(5, 2) NOT NULL DEFAULT 20.0,
  commission_amount INT NOT NULL DEFAULT 0,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'earned', -- 'earned', 'cancelled'
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 20. CRM & LEADS
CREATE TABLE IF NOT EXISTS public.leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID REFERENCES public.partners(id),
  business_name TEXT NOT NULL,
  contact_name TEXT,
  phone TEXT,
  email TEXT,
  city TEXT,
  business_type TEXT NOT NULL DEFAULT 'retail',
  status public.lead_status NOT NULL DEFAULT 'new',
  estimated_deal_value INT DEFAULT 0,
  notes TEXT,
  lost_reason TEXT,
  converted_business_id UUID REFERENCES public.businesses(id),
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.lead_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  partner_id UUID REFERENCES public.partners(id),
  activity_type TEXT NOT NULL, -- 'whatsapp', 'call', 'meeting', 'demo', 'note'
  notes TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.quotations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID REFERENCES public.leads(id),
  partner_id UUID REFERENCES public.partners(id),
  quote_number TEXT UNIQUE NOT NULL,
  client_name TEXT NOT NULL,
  client_business_name TEXT NOT NULL,
  client_phone TEXT,
  items JSONB NOT NULL DEFAULT '[]',
  subtotal INT NOT NULL DEFAULT 0,
  discount_amount INT NOT NULL DEFAULT 0,
  final_amount INT NOT NULL DEFAULT 0,
  valid_until DATE,
  status TEXT NOT NULL DEFAULT 'draft',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 21. ANNOUNCEMENTS & LICENSES
CREATE TABLE IF NOT EXISTS public.system_announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  target_audience TEXT NOT NULL DEFAULT 'all', -- 'all', 'merchants', 'cashiers'
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.app_licenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  app_code TEXT NOT NULL, -- 'batiku', 'kosanku', 'manggo_pos'
  license_key TEXT UNIQUE NOT NULL,
  client_name TEXT NOT NULL,
  machine_id TEXT,
  license_type TEXT NOT NULL DEFAULT 'offline_lifetime',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  expires_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 22. SYUPEO CLOSED-LOOP SUPPLY CHAIN (Gudang, Master Produk, Restock Toko)
CREATE TABLE IF NOT EXISTS public.warehouses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL, -- e.g. 'WH-JKT-01'
  name TEXT NOT NULL,
  warehouse_type VARCHAR(50) NOT NULL DEFAULT 'syupeo_hub',
  brand_partner VARCHAR(255),
  address TEXT NOT NULL,
  city VARCHAR(100) NOT NULL DEFAULT 'Indonesia',
  province VARCHAR(100),
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  coverage_radius_km NUMERIC(5, 2) DEFAULT 25.0,
  pic_name TEXT NOT NULL,
  pic_phone TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 21. MASTER CATALOG (Katalog Barcode Nasional Syupeo untuk POS & Admin)
CREATE TABLE IF NOT EXISTS public.master_catalog (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  barcode TEXT UNIQUE,
  name TEXT NOT NULL,
  category TEXT DEFAULT 'UMUM',
  brand TEXT,
  base_price NUMERIC DEFAULT 0,    -- Harga Modal / Grosir Pabrik
  selling_price NUMERIC DEFAULT 0, -- Harga Eceran Tertinggi (HET) / Rekomendasi
  unit TEXT DEFAULT 'Pcs',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_master_catalog_barcode ON public.master_catalog(barcode);
CREATE INDEX IF NOT EXISTS idx_master_catalog_category ON public.master_catalog(category);
CREATE INDEX IF NOT EXISTS idx_master_catalog_name_trgm ON public.master_catalog USING gin(name gin_trgm_ops);

ALTER TABLE public.master_catalog ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view master catalog" ON public.master_catalog;
CREATE POLICY "Anyone can view master catalog" ON public.master_catalog FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins can insert master catalog" ON public.master_catalog;
CREATE POLICY "Admins can insert master catalog" ON public.master_catalog FOR INSERT
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can update master catalog" ON public.master_catalog;
CREATE POLICY "Admins can update master catalog" ON public.master_catalog FOR UPDATE
USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can delete master catalog" ON public.master_catalog;
CREATE POLICY "Admins can delete master catalog" ON public.master_catalog FOR DELETE
USING (public.is_admin());

CREATE TABLE IF NOT EXISTS public.master_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sku TEXT UNIQUE NOT NULL,
  barcode TEXT UNIQUE,
  name TEXT NOT NULL,
  brand TEXT,
  category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
  description TEXT,
  image_url TEXT,
  package_unit TEXT NOT NULL DEFAULT 'Pcs',
  pcs_per_package INT NOT NULL DEFAULT 1,
  factory_buy_price INT NOT NULL DEFAULT 0,
  partner_wholesale_price INT NOT NULL DEFAULT 0,
  recommended_retail_price INT NOT NULL DEFAULT 0,
  min_order_qty INT NOT NULL DEFAULT 1,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.warehouse_inventories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID NOT NULL REFERENCES public.warehouses(id) ON DELETE CASCADE,
  master_product_id UUID NOT NULL REFERENCES public.master_products(id) ON DELETE CASCADE,
  stock_quantity INT NOT NULL DEFAULT 0,
  safety_stock_threshold INT NOT NULL DEFAULT 10,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(warehouse_id, master_product_id)
);

CREATE TABLE IF NOT EXISTS public.restock_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_code TEXT UNIQUE NOT NULL, -- e.g. 'RO-202610-0001'
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  warehouse_id UUID NOT NULL REFERENCES public.warehouses(id),
  total_amount INT NOT NULL DEFAULT 0,
  payment_terms TEXT NOT NULL DEFAULT 'cod',
  delivery_method TEXT NOT NULL DEFAULT 'delivery',
  shipping_address TEXT,
  shipping_notes TEXT,
  status public.restock_order_status NOT NULL DEFAULT 'submitted',
  driver_name TEXT,
  driver_phone TEXT,
  dispatched_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.restock_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restock_order_id UUID NOT NULL REFERENCES public.restock_orders(id) ON DELETE CASCADE,
  master_product_id UUID NOT NULL REFERENCES public.master_products(id),
  quantity INT NOT NULL,
  unit_price INT NOT NULL,
  subtotal INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.product_request_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  product_name TEXT NOT NULL,
  brand_or_vendor TEXT,
  sample_barcode TEXT,
  expected_selling_price INT,
  estimated_monthly_demand INT,
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  admin_response_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 23. ESSENTIAL FUNCTIONS & PERMISSIONS
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE email = lower(auth.jwt() ->> 'email')
      AND is_active = true
      AND role IN ('super_admin', 'admin')
  ) OR (lower(auth.jwt() ->> 'email') = 'diyanto2911@gmail.com');
$$;

CREATE OR REPLACE FUNCTION public.get_current_partner_id()
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT partner_id FROM public.admin_users
  WHERE email = lower(auth.jwt() ->> 'email')
    AND is_active = true
    AND role = 'partner'
  LIMIT 1;
$$;

-- Otomatis buat profil saat ada user signup via Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, phone, avatar_url, role)
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.phone,
    new.raw_user_meta_data->>'avatar_url',
    'owner'
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      full_name = COALESCE(EXCLUDED.full_name, public.profiles.full_name);
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 24. SEED INITIAL SUPER ADMIN & BASIC TEMPLATES
INSERT INTO public.admin_users (email, name, role, is_active, can_manage_licenses)
VALUES ('diyanto2911@gmail.com', 'Diyanto (Super Admin)', 'super_admin', true, true)
ON CONFLICT (email) DO UPDATE
SET role = 'super_admin', is_active = true, can_manage_licenses = true;

INSERT INTO public.business_type_templates (name, code, description, max_transactions, max_products, max_outlets)
VALUES
  ('Toko Kelontong & Retail', 'retail', 'Template kasir toko kelontong, sembako, dan minimarket mandiri', 10000, 5000, 5),
  ('Warung Makan & F&B', 'fnb', 'Template rumah makan, kafe, dan kedai minuman dengan resep BoM', 10000, 1000, 5),
  ('Jasa & Layanan', 'service', 'Template barbershop, laundry, dan bengkel', 5000, 200, 2)
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.subscription_plans (name, code, price_monthly, max_transactions_month, max_products, max_outlets)
VALUES
  ('Gratis Selamanya (Mitra Syupeo)', 'free', 0, 100000, 5000, 5),
  ('Syupeo Pro Enterprise', 'pro', 99000, 1000000, 20000, 20)
ON CONFLICT (code) DO NOTHING;

-- 25. SEED 4 PAKET USAHA RETAIL SYUPEO (@ RP 200.000)
INSERT INTO public.retail_starter_kits (
  slug,
  name,
  badge,
  price,
  original_price,
  description,
  suitable_for,
  items_included,
  is_popular,
  is_active,
  sort_order
)
VALUES
  (
    'paket-01-toko-pemula',
    'Paket 01 — Toko Pemula',
    'FAVORIT KELUARGA 🌾',
    200000,
    240000,
    'Stok sembako & kebutuhan harian rutin yang paling cepat berputar di lingkungan perumahan.',
    'Tetangga, Usaha Rumahan, Kos-kosan, Komunitas Lingkungan',
    '[
      "Beras Premium 2 kg (Bahan Pokok)",
      "Minyak Goreng 1 Liter & Gula Pasir 1 kg",
      "Tepung Terigu 1 kg & Mi Instan Pilihan (5 pcs)",
      "Kopi Sachet Nikmat (10 pcs) & Teh Pilihan",
      "Sabun Mandi (2 pcs) & Sabun Cuci Piring",
      "Deterjen Pakaian & Pasta Gigi Keluarga",
      "Kecap Manis, Tisu & Perlengkapan Kemasan Toko",
      "Aplikasi Kasir POS & Backoffice Syupeo 100% GRATIS",
      "Web Toko Online Siap Pakai & Dukungan QRIS Kasir"
    ]'::jsonb,
    TRUE,
    TRUE,
    1
  ),
  (
    'paket-02-gen-z-box',
    'Paket 02 — Gen Z Box',
    'TREN VIRAL 🔥',
    200000,
    260000,
    'Aksesori kekinian & fashion items margin tinggi yang sangat diminati kalangan anak muda.',
    'Mahasiswa, Pelajar, Reseller Kampus, TikTok & Instagram Shop',
    '[
      "Phone Charm Kekinian (5 pcs)",
      "Pop Socket Karakter Trendi (3 pcs)",
      "Pelindung Kabel Handphone (5 pcs)",
      "Scrunchie Rambut (5 pcs) & Jepit Rambut Korea (4 pcs)",
      "Gantungan Kunci Estetik (5 pcs) & Stiker Pack (10 pcs)",
      "Kaos Kaki Korea Stylish (3 pasang)",
      "Mini Tote Bag (2 pcs) & Mini Pouch Cantik (2 pcs)",
      "Alokasi Kemasan Estetik Siap Display",
      "Aplikasi Kasir POS & Backoffice Syupeo 100% GRATIS",
      "Katalog Online untuk Share Status WA & Medsos"
    ]'::jsonb,
    FALSE,
    TRUE,
    2
  ),
  (
    'paket-03-beauty-box',
    'Paket 03 — Beauty Box Makarizo',
    'STOK RESELLER 💄',
    200000,
    250000,
    'Stok produk perawatan & kecantikan resmi Makarizo untuk dijual kembali dengan margin menarik.',
    'Reseller Kecantikan, Mahasiswi, Salon Rumahan, Beauty Content Creator',
    '[
      "Produk Perawatan Rambut & Tubuh Makarizo Resmi",
      "Produk Kecantikan Pelengkap Terlaris",
      "Kemasan Reseller Eksklusif (Pouch & Label Toko)",
      "Cadangan Biaya Operasional & Kemasan Rapi",
      "Materi Promosi Foto Produk Asli & Konten Video Pendek",
      "Aplikasi Kasir POS & Backoffice Syupeo 100% GRATIS",
      "Toko Online Pribadi untuk Terima Order Langsung"
    ]'::jsonb,
    FALSE,
    TRUE,
    3
  ),
  (
    'paket-04-air-mineral',
    'Paket 04 — Air Mineral (VICA + Pure Life)',
    'KEBUTUHAN RUTIN 💧',
    200000,
    225000,
    'Paket air minum siap jual dari brand terpercaya dengan perputaran repeat order sangat tinggi.',
    'Warung, Rumah Tangga, Kantor Kecil, Kos-kosan, Tempat Usaha',
    '[
      "1 Karton VICA 600 mL Tutup Kuning (24 Botol) @ Rp 84.000",
      "1 Galon Nestlé Pure Life 19 Liter @ Rp 70.000",
      "Alokasi Kemasan & Cadangan Biaya Operasional @ Rp 46.000",
      "Acuan: VICA 600 mL Tutup Kuning Label Biru-Hijau Resmi",
      "Panduan Lengkap Kebijakan Galon & Mekanisme Penukaran",
      "Aplikasi Kasir POS & Backoffice Syupeo 100% GRATIS",
      "Pencatatan Pelanggan Rutin & Riwayat Order Otomatis"
    ]'::jsonb,
    FALSE,
    TRUE,
    4
  )
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  badge = EXCLUDED.badge,
  price = EXCLUDED.price,
  original_price = EXCLUDED.original_price,
  description = EXCLUDED.description,
  suitable_for = EXCLUDED.suitable_for,
  items_included = EXCLUDED.items_included,
  is_popular = EXCLUDED.is_popular,
  is_active = EXCLUDED.is_active,
  sort_order = EXCLUDED.sort_order,
  updated_at = timezone('utc'::text, now());

-- 26. GRANT PERMISSIONS TO POSTGRES, ANON, AUTHENTICATED & SERVICE_ROLE
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO postgres, anon, authenticated, service_role;

