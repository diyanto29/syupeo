# Panduan & Log Migrasi Database Syupeo

Dokumen ini mencatat konvensi dan daftar riwayat migrasi skema database PostgreSQL Supabase untuk platform **Syupeo**.

---

## 1. Konsep Sistem Migrasi Syupeo

### Format Penamaan File
Setiap file migrasi disimpan di direktori `supabase/migrations/` dengan format:
```text
YYYYMMDDHHMMSS_<nama_fitur_atau_perubahan>.sql
```
Contoh:
- `20261030100000_create_migration_tracker.sql`
- `20261030101500_migrate_hardware_packages_to_retail_starter_kits.sql`

### Registri Audit Internal (`public._syupeo_migrations`)
Setiap kali migrasi dijalankan, sistem secara otomatis mencatat versinya ke dalam tabel audit:
```sql
SELECT version, name, description, applied_at, applied_by 
FROM public._syupeo_migrations 
ORDER BY applied_at DESC;
```
Manfaat:
1. **Audit Trail Jelas**: Mengetahui versi skema database Supabase saat ini.
2. **Idempoten & Aman**: Script migrasi dirancang agar dapat dijalankan ulang tanpa menyebabkan duplikasi atau error tabrakan data (`ON CONFLICT DO UPDATE`).
3. **Mencegah Tabrakan Tipe Objek (Error 42809)**: Menghapus tabel/view lama dengan klausul `DROP ... CASCADE` sebelum merekonstruksi relasi baru.

---

## 2. Riwayat & Daftar Migrasi Syupeo (Era Baru)

| Versi | File Migrasi | Deskripsi Perubahan | Status |
| :--- | :--- | :--- | :--- |
| **Baseline** | `syupeo_complete_schema.sql` | Skema master fondasi awal (Profiles, Businesses, Outlets, Master Catalog, Categories, Warehouses, CRM, Auth Sync) | Baseline Master |
| **`20261030100000`** | [`20261030100000_create_migration_tracker.sql`](./migrations/20261030100000_create_migration_tracker.sql) | Pembuatan tabel audit registri migrasi `_syupeo_migrations` | Siap Dijalankan |
| **`20261030101500`** | [`20261030101500_migrate_hardware_packages_to_retail_starter_kits.sql`](./migrations/20261030101500_migrate_hardware_packages_to_retail_starter_kits.sql) | Menghapus tabel lama `hardware_packages`, membuat tabel resmi `retail_starter_kits`, membuat backward-compatibility view, dan memasukkan 4 Paket Usaha Retail Syupeo (@ Rp 200.000). | Siap Dijalankan |
| **`20261030103000`** | [`20261030103000_create_master_catalog.sql`](./migrations/20261030103000_create_master_catalog.sql) | Membuat tabel `master_catalog` (Katalog Barcode Nasional), index pencarian `pg_trgm`, RLS Super Admin, dan seed produk perdana. | Siap Dijalankan |
| **`20261030104500`** | [`20261030104500_create_starter_kit_items_relation.sql`](./migrations/20261030104500_create_starter_kit_items_relation.sql) | Membuat tabel relasi `retail_starter_kit_items` (BOM Paket Usaha) dan fungsi auto-seed kasir `apply_starter_kit_to_business`. | Siap Dijalankan |
| **`20261030110000`** | [`20261030110000_create_warehouses_and_fulfillment_dispatch.sql`](./migrations/20261030110000_create_warehouses_and_fulfillment_dispatch.sql) | Struktur Multi-Node Warehouses (Hub Syupeo vs Agen Pabrik Cleo/Unilever) dan Order Dispatch Tracking Pengiriman White-label. | Siap Dijalankan |

---

## 3. Cara Menjalankan Migrasi di Supabase

### Opsi A: Via Supabase SQL Editor (Rekomendasi untuk Web Console)
1. Buka [Supabase Dashboard SQL Editor](https://fgzmwmtssrviptflsjqy.supabase.co).
2. Buka file migrasi terbaru yang ingin diaplikasikan (misal: `20261030101500_migrate_hardware_packages_to_retail_starter_kits.sql`).
3. Copy isinya dan tekan **Run**.
4. Verifikasi dengan menjalankan kueri:
   ```sql
   SELECT * FROM public._syupeo_migrations;
   SELECT slug, name, price, badge FROM public.retail_starter_kits;
   ```

### Opsi B: Via Supabase CLI (Jika CLI Lokal Terhubung)
```bash
npx supabase db push
```

