---
name: dpos-pos-engine
description: Spesifikasi alur logika Point of Sale (POS), kalkulasi keranjang belanja, diskon (persen/nominal, PWP, BXGY), pajak (PB1 & PPN), struk dapur (KOT), manajemen shift kasir, dan antrian offline sync.
---

# Syupeo Core POS Engine Specification

Dokumen skill ini menjabarkan aturan bisnis dan kalkulasi matematis inti mesin kasir Syupeo.

---

## 1. Aturan Kalkulasi Transaksi Kasir

Semua kalkulasi nilai uang wajib dihitung menggunakan bilangan bulat (`int` Rupiah):

```text
Subtotal Kotor  = Σ (Harga Varian × Kuantitas)
Diskon Produk   = Σ (Diskon Per Item)
Subtotal Bersih = Subtotal Kotor - Diskon Produk
Diskon Transaksi= Diskon Global Toko (Nominal atau % terhadap Subtotal Bersih)
Dasar Pengenaan = Subtotal Bersih - Diskon Transaksi
Pajak (PB1/PPN) = Round((Dasar Pengenaan × Persentase Pajak) / 100)
Service Charge  = Round((Dasar Pengenaan × Persentase Service) / 100)
Total Akhir     = Dasar Pengenaan + Pajak + Service Charge
Kembalian       = Jumlah Uang Diterima - Total Akhir
```

### Standar Pembulatan:
- Jika ada pembulatan, bulatkan secara matematis ke atas/bawah terdekat (`(val).round()`).
- Kembalian tidak boleh negatif. Jika uang diterima < Total Akhir, transaksi ditolak sebagai pembayaran kurang.

---

## 2. Struktur Modul Kasir & State (`lib/features/pos/`)

- **State Notifier**: `PosStore` (`lib/features/pos/state/pos_store.dart`)
  - Menyimpan item keranjang aktif (`List<CartItem>`), outlet terpilih, diskon aktif, pelanggan terpilih, dan metode pembayaran.
- **Model Data**: `lib/features/pos/domain/pos_models.dart`
  - `CartItem`: `product`, `quantity`, `selectedVariant`, `selectedAddons`, `notes`, `customPrice`.
  - `OrderPayment`: `paymentMethod` (`cash`, `qris`, `debit`, `credit`, `transfer`, `debt`), `amount`.

---

## 3. Sistem Tiket Dapur (Kitchen Order Ticket / KOT)

1. **Alur Pesanan Meja & Dapur:**
   - Kasir memilih meja/pesanan -> Tambah menu -> Klik "Kirim ke Dapur".
   - Status pesanan bergerak: `menunggu_dapur` -> `dimasak` -> `siap_saji` -> `selesai`.
2. **Filter Cetak KOT:**
   - Hanya item dengan kategori bertipe F&B yang dicetak ke printer dapur.
   - Item retail atau minuman kemasan dapat dipisahkan ke printer bar jika outlet memiliki multi-printer.

---

## 4. Manajemen Shift & Cash Drawer

- **Buka Shift (`shifts`):**
  - Kasir memasukkan modal awal kas kecil (`initial_cash`).
- **Pencatatan Arus Kas (`cash_flows`):**
  - Tipe `cash_in`: Setoran kas tambahan / penyesuaian modal.
  - Tipe `cash_out`: Pengeluaran operasional (beli es batu, gas, galon air).
- **Tutup Shift:**
  - Kasir memasukkan uang fisik aktual di laci (`actual_cash`).
  - Sistem menghitung selisih (`variance = actual_cash - expected_cash`).
  - Cetak struk laporan ringkasan shift (Total Cash, QRIS, Transfer, Void, Selisih).

---

## 5. Offline-First Resilience & Sync Engine

- Layanan: `OfflineSyncService` (`lib/core/services/offline_sync_service.dart`)
- **Mekanisme Penyimpanan:**
  - Ketika perangkat tidak memiliki koneksi internet, order tetap disimpan ke SQLite lokal (`local_database_service.dart`) dengan status `sync_status = 'pending'`.
- **Mekanisme Sinkronisasi Otomatis:**
  - `ConnectivityListener` mendeteksi kembalinya jaringan internet.
  - Antrian pending dikirimkan batch ke Supabase melalui RPC atau bulk insert.
  - Item yang berhasil disinkronkan diperbarui statusnya menjadi `sync_status = 'synced'`.

---

## 6. Multi-Satuan (Multi-UOM) & Konversi Karton ke Eceran

Sesuai dokumen spesifikasi di `docs/SPESIFIKASI_TRANSAKSI_POS_DAN_MULTI_SATUAN.md`:

1. **Konsep Satu Stok Induk (*Base Unit*):**
   - Database hanya mencatat stok dalam satuan dasar terkecil (`Pcs`, `Bungkus`, `Botol`).
   - Setiap produk memiliki pengali kemasan besar (`conversion_ratio`), misal 1 Karton Indomie = 40 Pcs, 1 Karton Teh Pucuk = 24 Botol.
2. **Kalkulasi Pemotongan Stok Transaksi:**
   $$\text{Stok Berkurang} = \sum (\text{Qty Terjual} \times \text{Multiplier Satuan})$$
   Contoh: Pembelian `1 Dus (40 Pcs) + 3 Eceran` memotong $40 + 3 = 43\text{ Pcs}$ stok dasar secara atomik.
3. **Fleksibilitas Barcode:**
   - Barcode kemasan luar (Dus/Karton) bersifat **opsional**.
   - Jika barcode dus di-scan, item otomatis masuk dengan satuan kemasan besar.
   - Jika hanya barcode eceran yang di-scan, kasir dapat memilih toggle satuan *[ Pcs | Dus ]* pada layar dialog kasir.
