-- Migration: Add Subscription Plans and Feature Control
-- Date: 2026-05-11

-- 1. Create Subscription Plans table
create table if not exists public.subscription_plans (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    code text not null unique,
    max_transactions_month int not null default 100,
    max_products int not null default 50,
    max_outlets int not null default 1,
    features jsonb not null default '{
        "tiered_pricing": false,
        "qr_ordering": false,
        "kds": false,
        "table_management": false,
        "advanced_reports": false, 
        "inventory_management": false,
        "barcode_scanner": false,
        "realtime_notifications": false
    }'::jsonb,
    price_monthly numeric not null default 0,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

-- 2. Add plan reference to businesses
alter table public.businesses 
add column if not exists plan_id uuid references public.subscription_plans(id),
add column if not exists subscription_status text not null default 'active',
add column if not exists subscription_end_at timestamptz;

-- 3. Seed initial plans
insert into public.subscription_plans (name, code, max_transactions_month, max_products, max_outlets, price_monthly, features)
values 
('Free Plan', 'free', 150, 50, 1, 0, '{
    "tiered_pricing": false, 
    "qr_ordering": false, 
    "kds": false, 
    "table_management": false,
    "advanced_reports": false,
    "inventory_management": false,
    "barcode_scanner": true,
    "realtime_notifications": false
}'),
('Pro Plan', 'pro', 999999, 999999, 5, 150000, '{
    "tiered_pricing": true, 
    "qr_ordering": true, 
    "kds": true, 
    "table_management": true,
    "advanced_reports": true,
    "inventory_management": true,
    "barcode_scanner": true,
    "realtime_notifications": true
}'),
('Enterprise', 'enterprise', 999999, 999999, 99, 500000, '{
    "tiered_pricing": true, 
    "qr_ordering": true, 
    "kds": true, 
    "table_management": true,
    "advanced_reports": true,
    "inventory_management": true,
    "barcode_scanner": true,
    "realtime_notifications": true
}')
on conflict (code) do update 
set 
    max_transactions_month = excluded.max_transactions_month,
    max_products = excluded.max_products,
    max_outlets = excluded.max_outlets,
    features = excluded.features,
    price_monthly = excluded.price_monthly;

-- 4. Function to automatically set Free Plan for new businesses
create or replace function public.handle_new_business_plan()
returns trigger
language plpgsql
as $$
declare
    free_plan_id uuid;
begin
    select id into free_plan_id from public.subscription_plans where code = 'free';
    new.plan_id := free_plan_id;
    return new;
end;
$$;

drop trigger if exists on_business_created_set_plan on public.businesses;

create trigger on_business_created_set_plan
before insert on public.businesses
for each row
execute function public.handle_new_business_plan();

-- 5. Enable RLS for subscription_plans
alter table public.subscription_plans enable row level security;

drop policy if exists "Allow all to read plans" on public.subscription_plans;

create policy "Allow all to read plans"
on public.subscription_plans
for select
to authenticated
using (true);
