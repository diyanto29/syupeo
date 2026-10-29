import { createClient } from '@supabase/supabase-js';

/**
 * Supabase Client khusus KosanKu Cloud (Multi-Project Super Admin)
 * Menggunakan Service Role Key untuk bypass RLS agar Super Admin dapat
 * mengelola paket langganan, mengaktivasi lisensi, dan memantau cloud.
 * Kunci Service Role WAJIB disetel di environment variable server (.env.local / Vercel).
 */
export function getKosankuAdminSupabase() {
  const url =
    process.env.NEXT_PUBLIC_KOSANKU_SUPABASE_URL ||
    'https://uepgmfoyrscssdnshkow.supabase.co';

  const key = process.env.KOSANKU_SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !key) {
    throw new Error('Kredensial Supabase KosanKu (KOSANKU_SUPABASE_SERVICE_ROLE_KEY) belum diatur di environment variable');
  }

  return createClient(url, key, {
    auth: { persistSession: false },
  });
}
