# DPOS Super Admin Web

Portal manajemen super admin untuk sistem Point of Sale (DPOS) berbasis **Next.js 14**, **Tailwind CSS**, dan **Supabase**. Didesain khusus untuk di-deploy secara mudah dan ringan di **Vercel**.

---

## 🚀 Fitur Utama

1. **Google SSO Login (`diyanto2911@gmail.com`)**:
   - Autentikasi menggunakan Google OAuth via Supabase Auth.
   - Proteksi ganda: Server-side Next.js Middleware & PostgreSQL Row Level Security (RLS). Akun selain `diyanto2911@gmail.com` akan otomatis ditolak dan di-sign out.

2. **Ringkasan Sistem (Dashboard Overview)**:
   - Statistik real-time total akun bisnis terdaftar, jumlah template aktif, dan total akun owner.
   - Daftar bisnis terbaru yang bergabung.

3. **Kelola Template Bisnis (`business_type_templates`)**:
   - Tambah, edit, dan hapus template bisnis (FnB, Retail, Barbershop / Layanan, General, dll).
   - Atur modul aktif bawaan (Kasir POS, Manajemen Pesanan, Katalog Menu, QR Meja, Kitchen Display KDS, Stok & Inventaris, dsb).
   - Konfigurasi batasan kuota default (maksimal transaksi, maksimal produk, dan maksimal outlet).

4. **Manajemen Akun Bisnis (`businesses`)**:
   - Cari dan filter seluruh bisnis terdaftar di DPOS.
   - **Ganti Template Bisnis**: Mengubah jenis template mitra (otomatis memperbarui limit dan modul aktif).
   - **Override Custom Limits**: Mengatur batas kuota khusus untuk mitra tertentu jika membutuhkan lebih banyak outlet atau produk.

5. **Pengaturan Sistem**:
   - Status koneksi Supabase & Google OAuth Client ID.
   - Panduan konfigurasi domain Vercel.

---

## 🛠️ Menjalankan Secara Lokal

```bash
cd admin_web
npm install
npm run dev
```

Buka [http://localhost:3000](http://localhost:3000) di browser Anda.

---

## 🌐 Deployment ke Vercel

1. Push perubahan ini ke GitHub:
   ```bash
   git add .
   git commit -m "feat: Add DPOS Super Admin Web"
   git push origin main
   ```
2. Buka dashboard [Vercel](https://vercel.com) dan klik **Add New Project** -> **Import Git Repository**.
3. Pada pengaturan proyek:
   - **Root Directory**: pilih `admin_web`
   - **Framework Preset**: Next.js
4. Tambahkan Environment Variables di Vercel:
   - `NEXT_PUBLIC_SUPABASE_URL`: URL project Supabase Anda
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`: Anon Key Supabase Anda
   - `NEXT_PUBLIC_SUPER_ADMIN_EMAIL`: `diyanto2911@gmail.com`
5. Klik **Deploy**!

---

## 🔐 Konfigurasi Domain Setelah Deploy ke Vercel

Setelah mendapatkan domain dari Vercel (contoh: `https://dpos-admin.vercel.app`):
1. **Supabase Dashboard**:
   - Buka menu **Authentication** > **URL Configuration**.
   - Tambahkan URL: `https://dpos-admin.vercel.app/auth/callback` ke dalam **Redirect URLs**.
2. **Google Cloud Console**:
   - Buka **APIs & Services** > **Credentials** > pilih OAuth 2.0 Client ID web Anda.
   - Tambahkan `https://dpos-admin.vercel.app` pada **Authorized JavaScript origins**.
   - Tambahkan `https://dpos-admin.vercel.app/auth/callback` pada **Authorized redirect URIs**.
