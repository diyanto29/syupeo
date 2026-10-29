---
name: dpos-supabase-backend
description: Panduan dan spesifikasi arsitektur backend PostgreSQL Supabase untuk DPOS (Mangga POS). Digunakan saat membuat query, migrasi, menangani skema database, RLS (Row Level Security), fungsi RPC (is_admin, get_current_partner_id), transaksi, inventori, dan realtime sync.
---

# DPOS Supabase Backend & Database Architecture Guide

Dokumen skill ini adalah referensi otoritatif untuk backend Supabase PostgreSQL DPOS (Mangga POS), mencakup struktur tabel, relasi, Row Level Security (RLS), dan fungsi database tersimpan (Stored Procedures / RPC).

---

## 1. Konfigurasi Kredensial & Lingkungan

- **Supabase URL**: `https://kjekiseloobdxomicolo.supabase.co`
- **Client Library**:
  - Flutter Mobile: `supabase_flutter: ^2.12.2` (via `SupabaseService.client` di `lib/core/supabase/`)
  - Web Admin: `@supabase/ssr` (via `@/lib/supabase/client` dan `@/lib/supabase/server`)
- **Multi-Tenant Hierarchy**:
  ```text
  auth.users (Auth UID)
    └── public.businesses (owner_user_id)
          ├── public.business_members (staff, kasir, manajer)
          ├── public.outlets (cabang / cabang toko)
          │     ├── public.orders (transaksi penjualan)
          │     │     ├── public.order_items
          │     │     └── public.order_payments
          │     ├── public.shifts (buka / tutup kasir)
          │     └── public.cash_flows (pemasukan / pengeluaran kas)
          ├── public.categories (kategori produk)
          ├── public.products (katalog produk & varian)
          ├── public.inventory_items (stok bahan / barang retail)
          └── public.fnb_recipes (resep BoM F&B)
  ```

---

## 2. Peta Tabel Utama (Database Schema Map)

### A. Bisnis, Outlet & Kemitraan
| Nama Tabel | Deskripsi | Kunci Utama / Relasi Kunci |
|---|---|---|
| `public.businesses` | Profil entitas bisnis / toko | `id` (UUID), `owner_user_id` (auth.users), `referred_by_partner_id` |
| `public.business_members` | Akses staf, kasir, manajer | `business_id`, `user_id`, `role` (`owner`, `manager`, `cashier`, `kitchen`) |
| `public.outlets` | Cabang toko / fisik outlet | `id` (UUID), `business_id` |
| `public.admin_users` | Master admin portal & akun mitra | `email`, `role` (`super_admin`, `admin`, `partner`), `partner_id`, `is_active` |
| `public.partners` | Data affiliate / mitra referal | `id` (UUID), `referral_code`, `commission_rate`, `bank_account_number` |
| `public.subscription_histories` | Log langganan & aktivasi PRO | `business_id`, `plan_id`, `partner_id`, `payment_status` |

### B. Katalog & Transaksi Kasir
| Nama Tabel | Deskripsi | Kunci Utama / Relasi Kunci |
|---|---|---|
| `public.categories` | Kategori produk toko | `id`, `business_id`, `name` |
| `public.products` | Produk toko (retail / menu F&B) | `id`, `business_id`, `category_id`, `barcode`, `price` (int), `cost_price` |
| `public.orders` | Header pesanan kasir | `id`, `outlet_id`, `order_number`, `total_amount` (int), `status` (`completed`, `cancelled`, `refunded`) |
| `public.order_items` | Rincian item pesanan | `order_id`, `product_id`, `quantity`, `unit_price`, `subtotal` |
| `public.order_payments` | Log pembayaran transaksi | `order_id`, `payment_method` (`cash`, `qris`, `transfer`, `debt`), `amount_paid` |
| `public.sales_returns` | Retur penjualan / refund | `order_id`, `outlet_id`, `refund_amount`, `return_type` (`exchange`, `refund_cash`) |

### C. Inventori & Resep F&B (BOM)
| Nama Tabel | Deskripsi | Kunci Utama / Relasi Kunci |
|---|---|---|
| `public.inventory_items` | Stok bahan mentah F&B / retail | `id`, `business_id`, `unit`, `current_stock`, `minimum_stock` |
| `public.fnb_recipes` | Header resep produk F&B | `id`, `business_id`, `product_id` |
| `public.fnb_recipe_items` | Bahan penyusun resep per porsi | `recipe_id`, `ingredient_id`, `quantity_required` |
| `public.stock_opnames` | Sesi stock opname fisik gudang | `id`, `outlet_id`, `status` (`draft`, `completed`) |
| `public.purchase_orders` | Pemesanan bahan ke supplier | `id`, `business_id`, `supplier_id`, `status` |

---

## 3. Aturan Row Level Security (RLS) & Best Practices

1. **Prinsip Isolasi Tenant:**
   - Semua query pengguna aplikasi **WAJIB** terfilter berdasarkan kepemilikan bisnis (`owner_user_id = auth.uid()` atau relasi `public.is_business_member(business_id, auth.uid())`).
2. **Fungsi Otorisasi Admin Global (`public.is_admin()`):**
   - Fungsi `public.is_admin()` memeriksa secara ketat `role IN ('super_admin', 'admin')`. Role `'partner'` **TIDAK** mendapatkan hak akses admin database.
   - Panggilan: `SELECT public.is_admin();`
3. **Pencarian Partner Aktif (`public.get_current_partner_id()`):**
   - Mengambil ID partner yang sedang login berdasarkan `auth.uid()` atau email JWT tanpa mengekspos tabel `auth.users`.
4. **Larangan Kebijakan `USING (true)`:**
   - Dilarang membuat RLS policy dengan `USING (true)` atau `WITH CHECK (true)` pada tabel administratif (`partners`, `app_licenses`, `subscription_histories`, dll.). Selalu gunakan `USING (public.is_admin())` untuk hak Super Admin.

---

## 4. Konvensi Tipe Data & Query di Supabase

- **Mata Uang (Rupiah):**
  - Selalu simpan nominal uang (`price`, `total_amount`, `discount_amount`, `cost_price`) sebagai **`BIGINT`** atau **`NUMERIC(15,0)`** (angka bulat Rupiah tanpa sen).
- **Stempel Waktu:**
  - Gunakan `TIMESTAMPTZ` (`timezone('utc'::text, now())`) untuk `created_at` dan `updated_at`.
- **Penanganan Offline Sync:**
  - Tambahkan kolom `client_id` (UUID) dan `is_synced` (boolean) saat merancang tabel transaksi lokal SQLite untuk mencegah duplikasi saat sinkronisasi ke Supabase.
