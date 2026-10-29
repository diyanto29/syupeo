import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

// Setup FCM
const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY");

serve(async (req) => {
  try {
    const payload = await req.json();
    const { record, type } = payload;

    // Only process inserts
    if (type !== 'INSERT') {
      return new Response("Not an insert", { status: 200 });
    }

    const outletId = record.outlet_id;
    const invoiceNumber = record.invoice_number;
    const tableNumber = record.table_number ? `Meja ${record.table_number}` : "Tanpa Meja";

    // Build FCM Message
    const message = {
      to: `/topics/outlet_${outletId}`,
      notification: {
        title: "Pesanan Baru Masuk!",
        body: `${tableNumber} baru saja memesan (${invoiceNumber})`,
        sound: "default",
      },
      data: {
        order_id: record.id,
        invoice_number: invoiceNumber,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      priority: "high",
    };

    // Send to FCM
    const fcmResponse = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `key=${FCM_SERVER_KEY}`,
      },
      body: JSON.stringify(message),
    });

    const result = await fcmResponse.json();
    console.log("FCM Result:", result);

    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    console.error("Error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    });
  }
});
