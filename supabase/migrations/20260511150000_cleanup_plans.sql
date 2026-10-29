-- 1. Bersihkan paket Enterprise
DELETE FROM public.subscription_plans WHERE code = 'enterprise';

-- 2. Update fitur untuk paket Free
UPDATE public.subscription_plans 
SET 
    name = 'Free Plan',
    max_transactions_month = 500, -- Naikkan sedikit biar menarik
    max_products = 50,
    max_outlets = 1,
    price_monthly = 0,
    features = '{
        "dashboard_sales": true,
        "order_notifications": true,
        "website_catalog": true,
        "staff_management": true,
        "transaction_history": true,
        "refund_void": true,
        "discount_management": true,
        "retail_catalog": true,
        "tiered_pricing": false, 
        "qr_ordering": false, 
        "kds": false, 
        "table_management": false,
        "inventory_management": false,
        "realtime_notifications": false
    }'::jsonb
WHERE code = 'free';

-- 3. Update fitur untuk paket Pro (Semua fitur aktif)
UPDATE public.subscription_plans 
SET 
    name = 'Pro Plan',
    max_transactions_month = 999999,
    max_products = 999999,
    max_outlets = 999999, -- Unlimited
    price_monthly = 150000,
    features = '{
        "dashboard_sales": true,
        "order_notifications": true,
        "website_catalog": true,
        "staff_management": true,
        "transaction_history": true,
        "refund_void": true,
        "discount_management": true,
        "retail_catalog": true,
        "tiered_pricing": true, 
        "qr_ordering": true, 
        "kds": true, 
        "table_management": true,
        "inventory_management": true,
        "realtime_notifications": true
    }'::jsonb
WHERE code = 'pro';

-- 4. Pastikan semua bisnis yang pakai plan Enterprise dipindah ke Pro atau Free (Safety check)
UPDATE public.businesses 
SET plan_id = (SELECT id FROM public.subscription_plans WHERE code = 'pro')
WHERE plan_id NOT IN (SELECT id FROM public.subscription_plans);
