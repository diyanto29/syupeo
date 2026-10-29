-- 1. Create a trigger function that calls our Edge Function
CREATE OR REPLACE FUNCTION public.on_order_inserted()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Call the Edge Function via HTTP (Standard Supabase Webhook pattern)
  -- Note: Replace '<YOUR_EDGE_FUNCTION_URL>' with your actual function URL
  -- and '<YOUR_SERVICE_ROLE_KEY>' with your service role key if needed.
  
  -- Alternatively, use Supabase Dashboard 'Webhooks' UI to point to:
  -- URL: https://<project-ref>.supabase.co/functions/v1/send-order-notification
  
  RETURN NEW;
END;
$$;

-- 2. Create the Trigger
-- NOTE: It's usually easier to use the Supabase Dashboard UI for Webhooks
-- but here is how you would do it in SQL if using pg_net or similar:
--
-- CREATE TRIGGER tr_send_order_notification
-- AFTER INSERT ON public.orders
-- FOR EACH ROW
-- EXECUTE FUNCTION public.on_order_inserted();

/*
GUIDE TO SETUP WEBHOOKS IN SUPABASE DASHBOARD:
1. Go to Database -> Webhooks.
2. Click "Enable Webhooks" if not enabled.
3. Click "Create a new webhook".
4. Name: send_order_notification
5. Table: orders
6. Events: INSERT
7. Type: HTTP Request
8. Method: POST
9. URL: https://<your-project-ref>.supabase.co/functions/v1/send-order-notification
10. Headers: 
    - Content-Type: application/json
    - Authorization: Bearer <YOUR_SERVICE_ROLE_KEY>
*/
