# DPOS Security Audit Checklist & Verification Matrix

Panduan checklist praktis untuk menjalankan audit keamanan berkala pada codebase DPOS.

---

## 1. Web & Server Actions Checklist (`admin_web`)

- [ ] **Server Actions Auth Guarding:**
  - Setiap fungsi bertanda `'use server'` memanggil `assertAuthorizedAdmin()` atau `assertAuthorizedMerchant()`.
  - Fungsi server actions tidak mengekspos logic rahasia (seperti algoritma HMAC serial key) ke client.
- [ ] **Secret Management:**
  - Tidak ada variabel `NEXT_PUBLIC_*` yang memuat service role key, webhook secrets, atau private API keys.
  - File `.env.local` dan file rahasia lainnya terdaftar di `.gitignore`.
- [ ] **CSRF & Origin Protection:**
  - Server Actions Next.js mengandalkan built-in Host / Origin header verification.
- [ ] **Input Sanitization & File Uploads:**
  - Parsing spreadsheet (Excel `.xlsx` / CSV) untuk katalog produk dibatasi ukuran file dan tipe MIME.
  - Komponen Markdown (`react-markdown`) tidak mengizinkan tag `<script>` atau skema URL `javascript:`.

---

## 2. Supabase PostgreSQL Checklist (`supabase/`)

- [ ] **Row Level Security (RLS) Enabled:**
  - Semua tabel di skema `public` memiliki status `ROW LEVEL SECURITY ENABLED`.
- [ ] **Tenant Scoping:**
  - Tabel transaksi (`orders`, `order_items`, `shifts`, `cash_flows`) wajib memverifikasi `business_id` atau `outlet_id` pemilik.
- [ ] **Administrative Table Protection:**
  - Tabel `admin_users`, `partners`, `app_licenses`, dan `subscription_histories` hanya dapat dibaca/diubah oleh Super Admin (`USING (public.is_admin())`).
- [ ] **Security Definer Function Hardening:**
  - Fungsi PostgreSQL dengan `SECURITY DEFINER` wajib menyetel `SET search_path = public` untuk mencegah search path hijacking.

---

## 3. Flutter POS App Checklist (`lib/`)

- [ ] **Secure Storage for Tokens:**
  - Access token dan refresh token Supabase disimpan di penyimpanan terenkripsi hardware (`flutter_secure_storage` / Keychain / Keystore).
  - Data sensitif tidak disimpan sebagai plain text di `SharedPreferences`.
- [ ] **Offline Transaction Queue Integrity:**
  - Setiap pesanan kasir lokal memiliki UUID `client_id` unik untuk menjamin idempotensi saat sinkronisasi (mencegah double-spending atau duplikasi omzet).
- [ ] **Shift & Cash Drawer Protection:**
  - Tindakan void transaksi atau pengeluaran kas laci (petty cash) mewajibkan otorisasi PIN manajer/owner.
- [ ] **Anti-Tampering Lisensi Offline:**
  - Verifikasi integritas lisensi offline menghitung checksum SHA-256 terhadap Machine ID/Hardware ID dan tanggal kedaluwarsa.

