# 🚀 Panduan Setup Supabase KosanKu & Integrasi Admin Panel (dpos/admin_web)

Dokumen ini berisi panduan langkah demi langkah untuk menyiapkan backend Supabase baru untuk **KosanKu Cloud** dan menghubungkannya ke **Admin Web dpos (`admin_web`)** agar Anda memiliki satu pintu pengelolaan super admin.

---

## 📌 1. Buat Project Baru di Supabase Console
1. Buka [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Klik **New Project**
3. Masukkan rincian:
   * **Name:** `KosanKu Cloud`
   * **Database Password:** Buat password yang kuat dan simpan
   * **Region:** `Singapore (ap-southeast-1)` (Paling cepat untuk pengguna Indonesia)
   * **Plan:** Free Tier
4. Tunggu 1–2 menit hingga database selesai disiapkan.

---

## 🗄️ 2. Jalankan Database Schema (SQL Migration)
1. Di Supabase Console KosanKu, masuk ke menu **SQL Editor** (ikon terminal di sidebar kiri).
2. Klik **New Query**.
3. Buka berkas schema yang telah kami sediakan di:  
   [`kosanku/supabase/schema.sql`](file:///Users/diyanto/kosanku/supabase/schema.sql)
4. Salin (copy) seluruh isi file tersebut dan tempel (paste) ke SQL Editor Supabase.
5. Klik tombol **Run** (atau `Ctrl + Enter` / `Cmd + Enter`).
6. Sukses! Seluruh tabel berikut otomatis terbuat lengkap dengan relasi (Foreign Key) dan Row Level Security (RLS):
   * `properties` (Profil Kos, Rekening, Logo, Peraturan)
   * `rooms` (Nomor Kamar, Lantai, Tipe, Harga, Status)
   * `tenants` (Nama Anak Kos, No HP, NIK, Pekerjaan, KTP)
   * `room_tenants` (Penempatan Kamar & Riwayat Check-in)
   * `bills` (Tagihan Sewa Bulanan)
   * `payments` (Kuitansi Pembayaran & Bukti Transfer)
   * `expenses` (Buku Kas Pengeluaran & Operasional)
   * `room_renovations` (Riwayat Servis AC, Renovasi & Tukang)
   * `user_licenses` (Hardware ID, Serial Key, Paket Mandiri/Cloud, Masa Berlaku)

---

## 🔑 3. Dapatkan Kredensial API Supabase KosanKu
Masuk ke menu **Project Settings** -> **API** di Supabase KosanKu, lalu salin:
1. **Project URL** (misal: `https://abcdefghijkl.supabase.co`)
2. **Project API Keys:**
   * `anon` / `public` key
   * `service_role` / `secret` key (Wajib dirahasiakan, dipakai admin panel)

---

## 💻 4. Integrasikan ke Admin Panel dpos (`admin_web`)

### A. Tambahkan ke `.env.local` di `dpos/admin_web`
Buka file `dpos/admin_web/.env.local`, lalu tambahkan baris berikut di paling bawah:

```env
# ─────────────────────────────────────────────────────────────
# KOSANKU SUPABASE BACKEND (Multi-Project Admin)
# ─────────────────────────────────────────────────────────────
NEXT_PUBLIC_KOSANKU_SUPABASE_URL=https://uepgmfoyrscssdnshkow.supabase.co
NEXT_PUBLIC_KOSANKU_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVlcGdtZm95cnNjc3NkbnNoa293Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2MDQzOTUsImV4cCI6MjEwNzE4MDM5NX0.W29gzSyNkNKv_lJoh0Tfljhv7wra9KHxOrsU6Bb0TgU
# Service role key dapat Anda salin dari Supabase Console -> Project Settings -> API
KOSANKU_SUPABASE_SERVICE_ROLE_KEY=YOUR_KOSANKU_SERVICE_ROLE_KEY_HERE
```

---

### B. Buat Client Helper di `dpos/admin_web/src/lib/supabase/kosankuServer.ts`
Buat file baru di path tersebut untuk membaca database KosanKu dari sisi Server Action / API Route admin:

```typescript
import { createClient } from '@supabase/supabase-js';

// Khusus Admin Web (Bypass RLS untuk memantau semua kosan & mengaktivasi lisensi)
export function getKosankuAdminSupabase() {
  const url = process.env.NEXT_PUBLIC_KOSANKU_SUPABASE_URL;
  const key = process.env.KOSANKU_SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_KOSANKU_SUPABASE_ANON_KEY;

  if (!url || !key) {
    throw new Error('Kredensial Supabase KosanKu belum diisi di .env.local');
  }

  return createClient(url, key, {
    auth: { persistSession: false },
  });
}
```

---

### C. Contoh Halaman Pemantau KosanKu di Admin Web
Buat halaman baru di `dpos/admin_web/src/app/dashboard/kosanku/page.tsx`:

```tsx
import { getKosankuAdminSupabase } from '@/lib/supabase/kosankuServer';

export default async function KosankuDashboardPage() {
  const supabase = getKosankuAdminSupabase();

  // Ambil metrik ringkasan
  const { count: totalProperties } = await supabase.from('properties').select('*', { count: 'exact', head: true });
  const { count: totalRooms } = await supabase.from('rooms').select('*', { count: 'exact', head: true });
  const { count: totalTenants } = await supabase.from('tenants').select('*', { count: 'exact', head: true });
  const { data: licenses } = await supabase.from('user_licenses').select('*').order('created_at', { ascending: false }).limit(10);

  return (
    <div className="p-6 space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">🏢 Monitoring KosanKu</h1>
          <p className="text-sm text-slate-500">Kelola properti kos aktif, lisensi pengguna, dan status sinkronisasi.</p>
        </div>
      </div>

      {/* Metric Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-sm">
          <p className="text-xs font-semibold text-slate-500">TOTAL PROPERTI KOST</p>
          <p className="text-3xl font-bold text-indigo-600 mt-1">{totalProperties || 0}</p>
        </div>
        <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-sm">
          <p className="text-xs font-semibold text-slate-500">TOTAL KAMAR TERDAFTAR</p>
          <p className="text-3xl font-bold text-emerald-600 mt-1">{totalRooms || 0}</p>
        </div>
        <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-sm">
          <p className="text-xs font-semibold text-slate-500">TOTAL PENGHUNI AKTIF</p>
          <p className="text-3xl font-bold text-blue-600 mt-1">{totalTenants || 0}</p>
        </div>
      </div>

      {/* Tabel Lisensi KosanKu */}
      <div className="bg-white rounded-xl border border-slate-200 overflow-hidden shadow-sm">
        <div className="px-5 py-4 border-b border-slate-100 flex justify-between items-center">
          <h2 className="font-bold text-slate-800">Lisensi & Langganan KosanKu Terakhir</h2>
        </div>
        <table className="w-full text-left text-sm">
          <thead className="bg-slate-50 text-slate-600 font-semibold text-xs border-b">
            <tr>
              <th className="p-4">Hardware ID</th>
              <th className="p-4">Paket</th>
              <th className="p-4">Status</th>
              <th className="p-4">Masa Berlaku</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {licenses && licenses.length > 0 ? (
              licenses.map((lic) => (
                <tr key={lic.id} className="hover:bg-slate-50">
                  <td className="p-4 font-mono font-medium">{lic.hardware_id}</td>
                  <td className="p-4">
                    <span className="px-2.5 py-1 rounded-md text-xs font-semibold bg-indigo-50 text-indigo-700">
                      {lic.plan_code}
                    </span>
                  </td>
                  <td className="p-4">
                    <span className={`px-2 py-0.5 rounded text-xs font-bold ${lic.is_active ? 'bg-emerald-100 text-emerald-700' : 'bg-rose-100 text-rose-700'}`}>
                      {lic.is_active ? 'AKTIF' : 'NONAKTIF'}
                    </span>
                  </td>
                  <td className="p-4 text-slate-500">{lic.expires_at ? new Date(lic.expires_at).toLocaleDateString('id-ID') : 'Lifetime (Permanen)'}</td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={4} className="p-6 text-center text-slate-400">Belum ada data lisensi tercatat.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
```

---

## 🎯 5. Hubungkan dengan Sistem Komisi Partner di `dpos`
Karena tabel `partners` sudah ada di database Supabase `dpos`:
* Saat ada calon juragan kos membeli lisensi KosanKu melalui referral mitra:
  * Anda cukup mencatat `partner_id` ke dalam riwayat pembayaran komisi di `dpos`.
  * Saldo komisi mitra langsung bertambah secara otomatis dalam 1 akun mitra tanpa perlu sistem komisi terpisah!
