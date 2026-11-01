---
name: dpos-admin-web
description: Panduan arsitektur dan standar pengembangan untuk portal Admin Web Syupeo (Next.js 16 App Router, Tailwind CSS, @supabase/ssr, Server Actions, otorisasi Super Admin, sistem lisensi offline, dan CRM kemitraan).
---

# Syupeo Admin Web Architecture & Standards Guide

Dokumen skill ini adalah referensi pengembangan untuk aplikasi **Admin Web** (`/admin_web`), portal web terpusat untuk pemilik bisnis, kasir/staf, dan Super Admin Syupeo.

---

## 1. Arsitektur Teknologi & Folder

- **Framework**: Next.js 16 (App Router) + TypeScript + Tailwind CSS
- **Autentikasi & Database**: `@supabase/ssr` (Cookie-based session)
- **Struktur Rute (`admin_web/src/app/`):**
  - `/login`: Halaman otentikasi (Google OAuth & Email/Password).
  - `/merchant/*`: Portal khusus merchant/owner toko (Katalog, Transaksi, Laporan, Stok, Kasir, Pengaturan Toko).
  - `/dashboard/*`: Portal khusus **Super Admin / Admin** (CRM Leads, Penawaran/Quotations, Mitra/Partners, Manajemen Lisensi BatiKu/KosanKu/ManggoPOS, KosanKu Cloud Manager).
  - `/api/*`: Rute API serverless (misal: `/api/ai/chat` dengan autentikasi sesi).

---

## 2. Standar Keamanan & Otorisasi

1. **Middleware Route Guarding (`src/lib/supabase/middleware.ts`):**
   - Rute `/dashboard/*` dilindungi ketat. Hanya akun dengan email master (`diyanto2911@gmail.com`) ATAU terdaftar di `admin_users` dengan status aktif dan `role IN ('super_admin', 'admin')` yang diizinkan masuk.
   - Akun dengan `role = 'partner'` dialihkan ke portal khusus mitra (`/dashboard/partners`).
2. **Server Actions Security (`'use server'`):**
   - Setiap Server Action yang menjalankan mutasi database **WAJIB** memanggil fungsi verifikasi sesi:
     ```typescript
     await assertAuthorizedAdmin();
     ```
   - Dilarang mengekspos endpoint `'use server'` tanpa otentikasi jika endpoint tersebut melakukan modifikasi lisensi, data pengguna, atau paket langganan.
3. **Penyimpanan Kredensial:**
   - Dilarang keras menaruh fallback hardcoded token (misal: JWT Service Role atau API Key Gemini) langsung di kode sumber. Semua kredensial wajib dibaca dari `process.env`.
4. **Sistem Lisensi Offline:**
   - Hashing HMAC-SHA256 untuk Serial Key lisensi offline (BatiKu, KosanKu, ManggoPOS) **WAJIB diproses di server** (`src/app/dashboard/licenses/actions.ts`), bukan di browser client component, guna mencegah ekstraksi secret key.

---

## 3. Integrasi Supabase Server vs Client

- **Server Components & Server Actions:**
  ```typescript
  import { createClient } from '@/lib/supabase/server';
  const supabase = await createClient();
  ```
- **Client Components (`'use client'`):**
  ```typescript
  import { createClient } from '@/lib/supabase/client';
  const supabase = createClient();
  ```
- **Multi-Project Supabase (KosanKu Cloud Super Admin):**
  - Menggunakan helper `getKosankuAdminSupabase()` dari `@/lib/supabase/kosankuServer` yang membaca `KOSANKU_SUPABASE_SERVICE_ROLE_KEY` dari environment variable server.

---

## 4. Standar Query & Pengurutan Data (Descending Rule)

- **Aturan Baku Pengurutan List Data (Mandatory):**
  - Setiap query daftar data (misal: Node Gudang/Warehouses, Starter Kits/Paket Usaha, Outlets, Pesanan Fulfillment/Dispatch, Master Catalog, CRM Leads, dll) **WAJIB diurutkan secara DESCENDING** berdasarkan waktu pembuatan:
    ```typescript
    .order('created_at', { ascending: false })
    ```
  - **Tujuan**: Memastikan entri atau data yang baru saja diinput oleh admin/merchant selalu langsung tampil di posisi paling atas (urutan pertama) secara instan tanpa perlu mencari atau menggulir ke bawah.
