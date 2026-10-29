# PANDUAN KONTEKS LENGKAP UNTUK AI PENGEMBANG DASHBOARD ADMIN
> **Dokumen ini dibuat khusus untuk dibaca oleh AI / Developer yang sedang membangun Web Dashboard Admin untuk sistem kasir "Mangga POS".**

---

## 1. Identitas & Profil Proyek
* **Nama Aplikasi**: **Mangga POS** (Sistem POS Kasir Modern UMKM & Retail)
* **Domain Resmi**: `mudahkan.online`
* **Android Application ID / Package Name**: `online.mudahkan.manggapos`
* **Git Repository**: `https://github.com/diyanto29/dpos.git`
* **Active Branch**: `free`
* **Platform Client**: Flutter (Android, Tablet, Web)

---

## 2. Kredensial & Konfigurasi Supabase Backend
Kedua aplikasi (Aplikasi Kasir Mobile & Dashboard Web Admin) terhubung ke **Project Supabase yang sama**:
* **Supabase Project URL**: `https://kjekiseloobdxomicolo.supabase.co`
* **Supabase Anon Public Key**:
  ```text
  eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtqZWtpc2Vsb29iZHhvbWljb2xvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA1OTM3OTMsImV4cCI6MjEwNjE2OTc5M30.csMbrT-zokTlb1SBplh_xRr9_Cpksk46OSJ0BQZTQB0
  ```
* **Google OAuth Web Client ID**:
  ```text
  617929816223-g6fo9dk64r0nc20gnfaqiqjutlcjotuq.apps.googleusercontent.com
  ```
* **File Skema Database**: [`supabase/schema_bundle.sql`](file:///Users/diyanto/dpos/supabase/schema_bundle.sql) *(berisi 58 file migrasi DDL lengkap yang sudah diurutkan dependensinya)*.

---

## 3. Struktur Database Utama (Core Schema)

### A. Tabel Pengguna & Profil (`public.profiles`)
Menyimpan pengguna yang mendaftar via Google Sign-In atau Email:
* `id` (UUID, Primary Key, references `auth.users.id`)
* `email` (TEXT)
* `phone` (TEXT)
* `full_name` (TEXT)
* `avatar_url` (TEXT)
* `default_role` (`public.app_role`: `'owner'`, `'admin'`, `'cashier'`, `'waiter'`, `'kitchen'`, `'customer'`)
* `is_active` (BOOLEAN)
* `onboarding_completed` (BOOLEAN)
* `created_at`, `updated_at` (TIMESTAMPTZ)

### B. Tabel Bisnis / Toko (`public.businesses`)
Setiap Owner memiliki satu atau lebih entitas bisnis/toko:
* `id` (UUID, Primary Key)
* `owner_user_id` (UUID, references `public.profiles.id`)
* `name` (TEXT) — Nama Toko/Warung (misal: "Toko Berkah")
* `slug` (TEXT)
* `business_type` (TEXT) — Contoh: `'retail'`, `'fnb'`, `'service'`
* `plan_id` (UUID, references `public.subscription_plans.id`) — **Menentukan paket FREE / PRO**
* `is_active` (BOOLEAN)
* `created_at`, `updated_at` (TIMESTAMPTZ)

### C. Tabel Paket Berlangganan (`public.subscription_plans`)
* `id` (UUID, Primary Key)
* `code` (TEXT) — `'free'`, `'pro'`, `'lifetime'`
* `name` (TEXT) — Contoh: "Paket Free", "Paket Pro Lifetime"
* `price_monthly` (NUMERIC)
* `max_outlets` (INTEGER)
* `features` (JSONB / ARRAY)

### D. Tabel Keanggotaan & Staf (`public.business_members`)
Menghubungkan user staf dengan bisnis owner:
* `id` (UUID, Primary Key)
* `business_id` (UUID, references `public.businesses.id`)
* `user_id` (UUID, references `public.profiles.id`)
* `role` (`app_role`: `'owner'`, `'admin'`, `'cashier'`, `'waiter'`, `'kitchen'`)
* `status` (`'active'`, `'invited'`, `'disabled'`)

### E. Tabel Cabang / Outlet (`public.outlets`)
* `id` (UUID, Primary Key)
* `business_id` (UUID, references `public.businesses.id`)
* `name` (TEXT) — Nama Cabang (misal: "Cabang Utama", "Cabang Pasar")
* `code` (TEXT)
* `address` (TEXT)
* `phone` (TEXT)
* `timezone` (TEXT) — `'Asia/Jakarta'`, `'Asia/Makassar'`, `'Asia/Jayapura'`
* `is_active` (BOOLEAN)

---

## 4. Mekanisme Upgrade Paket Pro (Tugas Utama Dashboard Admin)

Aplikasi kasir Mangga POS memiliki alur upgrade di mana pengguna menekan tombol WhatsApp ke Admin dengan pesan:
> *"Halo, saya ingin upgrade ke Paket Pro untuk bisnis [Nama Toko] (ID: [Business ID]). Mohon info langkah selanjutnya."*

### Cara Kerja Aktivasi di Dashboard Admin:
1. **Melihat Daftar Bisnis**:
   Admin menampilkan list dari tabel `public.businesses` yang di-join dengan `public.profiles` (untuk mengetahui nama pemilik & email) dan `public.subscription_plans`.
2. **Tombol "Upgrade ke PRO"**:
   Ketika Admin mengonfirmasi pembayaran pengguna, Dashboard Admin mengeksekusi query:
   ```sql
   UPDATE public.businesses
   SET plan_id = (SELECT id FROM public.subscription_plans WHERE code = 'pro' LIMIT 1),
       updated_at = NOW()
   WHERE id = '<BUSINESS_ID_PENGGUNA>';
   ```
3. **Efek Real-Time di Aplikasi Mobile**:
   Aplikasi Flutter Mangga POS menggunakan Riverpod yang me-refresh bootstrap toko. Begitu kolom `plan_id` di Supabase berubah menjadi ID paket PRO:
   - Badge akun langsung berubah menjadi **PRO**.
   - Seluruh batasan fitur (cetak struk Bluetooth, waiter order, manajemen meja, ekspor Excel laporan laba rugi, kuota outlet cabang) terbuka secara instan tanpa perlu restart aplikasi!

---

## 5. Ringkasan Desain & Filosofi
* **Warna Tema Utama**: Mangga Gedong Gincu (Warm Orange `#FF7A00`, Deep Amber `#C2410C`) dipadu Daun Mangga Hijau Segar (`#15803D`) dan Slate Charcoal (`#18181B`).
* **Prinsip Arsitektur**:
  - Transaksi ringan (teks JSON nota ~0.35 KB per transaksi).
  - Foto produk di-upload ke Storage bucket `menu-items` dalam format kompresi (WebP/JPEG 50-70 KB).
  - Kuota Supabase 500 MB sanggup menampung ribuan toko dan jutaan transaksi tanpa beban bengkak.

---

> **Catatan untuk AI Admin**: Gunakan Service Role Key atau RLS Policy Admin saat membangun Dashboard Admin di Supabase agar memiliki akses penuh untuk membaca dan mengupdate seluruh data bisnis pengguna.
