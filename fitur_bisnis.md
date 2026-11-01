# Dokumentasi Fitur Aplikasi Syupeo (Point of Sale & Retail Platform)

Dokumen ini merangkum fitur-fitur utama yang tersedia dalam aplikasi Syupeo, dikategorikan berdasarkan jenis usaha dan detail teknis lokasinya di dalam kode program.

---

## 🚀 Fitur Baru: Dynamic Business Type & Feature Mapping
Mulai Mei 2026, Syupeo menggunakan sistem **Dynamic Template** yang memungkinkan setiap bisnis memiliki fitur yang terpersonalisasi namun tetap fleksibel.

### A. Template Tipe Bisnis (Preset)
Setiap pemilik bisnis memilih tipe saat pendaftaran untuk mendapatkan konfigurasi awal:

| Tipe Bisnis | Fokus Utama | Fitur Default |
| :--- | :--- | :--- |
| **Cafe / Resto** | Operasional Meja & Dapur | Meja, KDS, QR Order, Menu Kompleks |
| **Retail / Toko** | Stok & Kecepatan | Barcode, Tiered Pricing, Stok Grosir |
| **Laundry** | Status Layanan | Tracking Cucian, Stok Deterjen |
| **Showroom** | Unit & Leads | Katalog Unit, Data Customer Detail |
| **Kuliner** | UMKM & Mobilitas | Menu Simpel, Transaksi Cepat |

### B. Dynamic Menu Visibility (Mapping)
Menu yang muncul di navigasi samping (`OwnerDrawer`) dikontrol secara dinamis berdasarkan kolom `enabled_features` di database:

*   **Core Menus (Selalu Tampil):** Beranda, Profil Bisnis, Manajemen Staf, Riwayat Transaksi, Pengaturan, Langganan.
*   **Dynamic Menus (Sesuai Fitur):**
    *   `transaction`, `order_mgmt`: Fitur Jualan dasar.
    *   `menu_mgmt`: Manajemen produk/jasa.
    *   `table_mgmt`: Manajemen Meja (Cafe).
    *   `kitchen_kds`: Antrian Dapur (Cafe).
    *   `inventory`: Stok & Supplier (Retail/Showroom).
    *   `qr_order`: Self-ordering (Cafe).
    *   `reports`: Analitik (Dapat diaktifkan untuk semua).

---

## 1. Resto & Cafe (Small Restaurant)
Fokus pada manajemen operasional tempat makan dan efisiensi pelayanan.

*   **Manajemen Meja (Table Management)**
    *   **Deskripsi:** Visualisasi status meja, pembukaan sesi meja, dan penggabungan tagihan.
    *   **Lokasi Kode:** `lib/features/table_session/`
    *   **File Utama:** `table_session_screen.dart`, `table_session_provider.dart`
*   **Self-Service QR Ordering**
    *   **Deskripsi:** Pelanggan dapat memesan langsung melalui scan QR code tanpa aplikasi tambahan.
    *   **Lokasi Kode:** `lib/features/customer_ordering/`
    *   **File Utama:** `customer_order_screen.dart`, `customer_ordering_repository.dart`
*   **Kitchen Display System (KDS)**
    *   **Deskripsi:** Monitor dapur untuk melihat pesanan masuk secara real-time.
    *   **Lokasi Kode:** Terintegrasi di `lib/features/pos/` dan fitur waiter.
*   **Manajemen Menu & Stok Bahan**
    *   **Deskripsi:** Pengurangan stok otomatis berdasarkan komposisi menu.
    *   **Lokasi Kode:** `lib/features/menu_management/`

---

## 2. Retail & Toko Sembako (Grocery Store)
Fokus pada kecepatan transaksi volume tinggi dan akurasi stok.

*   **Barcode Scanner Terintegrasi**
    *   **Deskripsi:** Input barang cepat menggunakan kamera atau scanner hardware.
    *   **Lokasi Kode:** `lib/features/transaction/presentation/widgets/product_grid.dart`
*   **Harga Bertingkat (Tiered Pricing)**
    *   **Deskripsi:** Harga otomatis berubah berdasarkan jumlah (Ecer vs Grosir).
    *   **Lokasi Kode:** `lib/features/transaction/state/cart_state.dart` (Logika kalkulasi).
*   **Manajemen Stok & Notifikasi**
    *   **Deskripsi:** Peringatan stok rendah dan manajemen supplier.
    *   **Lokasi Kode:** `lib/features/inventory/` dan `lib/features/notifications/`
*   **Pencatatan Hutang (Credit Tracking)**
    *   **Deskripsi:** Manajemen bon pelanggan dan riwayat pembayaran.
    *   **Lokasi Kode:** Terkait dengan fitur `lib/features/transaction/` dan data customer.

---

## 3. Kuliner & UMKM (Street Food / Stall)
Fokus pada mobilitas dan kemudahan penggunaan di layar kecil.

*   **Quick-Tap POS Interface**
    *   **Deskripsi:** Antarmuka yang dioptimalkan untuk tap cepat tanpa banyak langkah.
    *   **Lokasi Kode:** `lib/features/pos/presentation/`
*   **Opsi Modifikasi (Toppings/Add-ons)**
    *   **Deskripsi:** Custom order (misal: pedas, tambah keju) dengan harga otomatis.
    *   **Lokasi Kode:** `lib/features/menu_management/domain/menu_models.dart`
*   **Integrasi QRIS Dynamic**
    *   **Deskripsi:** Generate QRIS otomatis setiap transaksi selesai.
    *   **Lokasi Kode:** `lib/features/transaction/presentation/widgets/payment_screen.dart`
*   **Cetak Struk Bluetooth**
    *   **Deskripsi:** Mendukung berbagai printer termal portable.
    *   **Lokasi Kode:** `lib/features/transaction/data/receipt_service.dart`

---

## 4. Manajemen Bisnis (Owner & Admin)
*   **Profil Bisnis:** `/Users/diyanto/syupeo/lib/features/business_profile/`
*   **Laporan Penjualan (Analytics):** `/Users/diyanto/syupeo/lib/features/reports/`
*   **Manajemen Outlet:** `/Users/diyanto/syupeo/lib/features/outlet_management/`
*   **Manajemen Staf/Pegawai:** `/Users/diyanto/syupeo/lib/features/staff_management/`

---

## Detail Teknis Core
*   **Database:** Supabase (PostgreSQL + RLS)
*   **State Management:** Riverpod (Functional & Class-based)
*   **Dynamic Features:** Business Feature Flags (`enabled_features` array)
*   **Storage Gambar:** Supabase Storage
*   **Migrasi Database:** `supabase/migrations/`
*   **Lokasi Mapping Navigasi:** `lib/features/dashboard/presentation/navigation/owner_dashboard_navigation.dart`
