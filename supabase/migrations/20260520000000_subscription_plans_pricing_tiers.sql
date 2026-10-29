-- Migration: Add Dynamic Pricing Tiers to Subscription Plans and Super Admin RLS
-- Date: 2026-05-20

-- 1. Ensure table public.subscription_plans exists
create table if not exists public.subscription_plans (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    code text not null unique,
    max_transactions_month int not null default 150,
    max_products int not null default 50,
    max_outlets int not null default 1,
    features jsonb not null default '{
        "tiered_pricing": false,
        "qr_ordering": false,
        "kds": false,
        "table_management": false,
        "advanced_reports": false, 
        "inventory_management": false,
        "barcode_scanner": true,
        "realtime_notifications": false
    }'::jsonb,
    price_monthly numeric not null default 0,
    pricing_tiers jsonb not null default '{
        "1_month": 49000,
        "3_months": 129000,
        "6_months": 239000,
        "12_months": 399000,
        "lifetime": 799000
    }'::jsonb,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

-- 2. Add pricing_tiers column if table already exists
alter table public.subscription_plans
add column if not exists pricing_tiers jsonb not null default '{
    "1_month": 49000,
    "3_months": 129000,
    "6_months": 239000,
    "12_months": 399000,
    "lifetime": 799000
}'::jsonb;

-- 3. Upsert default Free and Pro plans
insert into public.subscription_plans (name, code, max_transactions_month, max_products, max_outlets, price_monthly, pricing_tiers, features)
values 
('Free Plan', 'free', 150, 50, 1, 0, '{}'::jsonb, '{
    "tiered_pricing": false, 
    "qr_ordering": false, 
    "kds": false, 
    "table_management": false,
    "advanced_reports": false,
    "inventory_management": false,
    "barcode_scanner": true,
    "realtime_notifications": false
}'::jsonb),
('Pro Plan', 'pro', 999999, 999999, 5, 49000, '{
    "1_month": 49000,
    "3_months": 129000,
    "6_months": 239000,
    "12_months": 399000,
    "lifetime": 799000
}'::jsonb, '{
    "tiered_pricing": true, 
    "qr_ordering": true, 
    "kds": true, 
    "table_management": true,
    "advanced_reports": true,
    "inventory_management": true,
    "barcode_scanner": true,
    "realtime_notifications": true
}'::jsonb)
on conflict (code) do update set
    pricing_tiers = excluded.pricing_tiers,
    price_monthly = excluded.price_monthly,
    updated_at = timezone('utc', now());

-- 4. Enable RLS and setup policies
alter table public.subscription_plans enable row level security;

-- Read policy: Everyone can view active plans
drop policy if exists "Allow all to read plans" on public.subscription_plans;
create policy "Allow all to read plans"
on public.subscription_plans
for select
using (true);

-- Admin policy: Super Admin can insert, update, delete
drop policy if exists "Allow super admin all on subscription_plans" on public.subscription_plans;
create policy "Allow super admin all on subscription_plans"
on public.subscription_plans
for all
to authenticated
using (auth.jwt() ->> 'email' = 'diyanto2911@gmail.com')
with check (auth.jwt() ->> 'email' = 'diyanto2911@gmail.com');
