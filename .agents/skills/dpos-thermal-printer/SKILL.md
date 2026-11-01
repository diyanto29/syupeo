---
name: dpos-thermal-printer
description: Panduan integrasi printer thermal Bluetooth ESC/POS (58mm dan 80mm), layout struk kasir, cetak QRIS, tiket dapur, perintah cash drawer, dan penanganan koneksi printer.
---

# Syupeo Thermal Printer & ESC/POS Protocol Guide

Dokumen skill ini memberikan spesifikasi teknis untuk modul pencetakan struk thermal Bluetooth di aplikasi Syupeo.

---

## 1. Dependensi & Arsitektur Cetak

- **Paket Bluetooth**: `print_bluetooth_thermal: ^1.1.9`
- **Paket ESC/POS**: `esc_pos_utils_plus: ^2.0.4`
- **Karakter Maksimum Per Baris:**
  - **Printer 58mm**: **32 karakter** per baris (`PaperSize.mm58`)
  - **Printer 80mm**: **48 karakter** per baris (`PaperSize.mm80`)

---

## 2. Struktur Layout Struk Kasir Standar

```text
================================
         [NAMA TOKO/OUTLET]
       Alamat Lengkap Toko
        Telp: 081234567890
================================
No. Pesanan : POS-20261028-001
Tanggal     : 28/10/2026 14:30
Kasir       : Siti (Shift Pagi)
Meja / Tipe : Meja 04 / Dine-In
--------------------------------
1x Kopi Susu Aren        18.000
   - Less Sugar (0)
   - Extra Shot (3.000)   3.000
2x Croissant Butter      44.000
   @22.000
--------------------------------
Subtotal                 65.000
Diskon Promo 10%         -6.500
PB1 (10%)                 5.850
--------------------------------
TOTAL                    64.350
TUNAI                   100.000
KEMBALIAN                35.650
================================
  Metode Bayar: CASH / TUNAI
  Terima Kasih Atas Kunjungan Anda!
   Powered by Syupeo
================================
```

---

## 3. Perintah Khusus ESC/POS (Hardware Controls)

1. **Buka Laci Kasir (Cash Drawer Kick):**
   ```dart
   // Kirim perintah ESC p sebelum cetak struk selesai (jika pembayaran tunai)
   bytes += generator.drawer();
   ```
2. **Pemotong Kertas Otomatis (Paper Cut):**
   - Hanya berlaku pada printer 80mm dengan fitur Auto-Cutter:
   ```dart
   bytes += generator.cut();
   ```
3. **Pemberian Umpan Kertas (Feed Paper):**
   - Selalu beri minimal 2-3 baris kosong di akhir sebelum potong kertas agar tulisan terakhir tidak terpotong di bibir printer:
   ```dart
   bytes += generator.feed(2);
   ```

---

## 4. Penanganan Kesalahan & Koneksi Bluetooth

- **State Persistence:**
  - Simpan alamat MAC printer (`printer_mac_address`) di `SharedPreferences` agar saat aplikasi dibuka kembali, kasir tidak perlu pairing manual.
- **Auto Reconnect:**
  - Sebelum mengirim payload byte, panggil `PrintBluetoothThermal.connectionStatus`.
  - Jika `false`, lakukan reconnect dengan MAC address tersimpan maksimal 2x percobaan. Jika gagal, tampilkan dialog/bottom sheet koneksi printer (`BluetoothPromptSheet`).
- **Pencetakan Non-Blocking:**
  - Operasi cetak **WAJIB** dijalankan secara asynchronous dan tidak boleh memblokir UI thread ataupun menunda transisi navigasi checkout.
