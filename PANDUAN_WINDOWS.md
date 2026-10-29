# 🖥️ Panduan Lengkap Mangga POS — Windows Desktop Edition

Selamat datang di panduan resmi **Mangga POS untuk Windows PC & Laptop Kasir**.  
Dokumen ini memandu Anda mulai dari proses instalasi aplikasi, pemasangan driver printer thermal kasir (USB/LAN), hingga pengoperasian fitur **Master-Detail (Split View)** khusus desktop.

---

## 1. Spesifikasi Minimum Sistem
- **Sistem Operasi**: Windows 10 (64-bit) atau Windows 11
- **Prosesor**: Intel Core i3 / AMD Ryzen 3 atau setara (disarankan dual-core 2.0 GHz+)
- **RAM**: Minimal 4 GB (Disarankan 8 GB untuk kelancaran multi-tasking)
- **Konektivitas**: Port USB 2.0/3.0 untuk printer struk kasir, koneksi Internet/WiFi (aplikasi tetap mendukung mode offline).

---

## 2. Cara Instalasi Aplikasi Mangga POS

1. **Unduh File Installer Resmi**:
   - [📥 **Download Mangga POS untuk Windows (ManggaPOS_Setup_v1.0.15.exe)**](https://drive.usercontent.google.com/download?id=1ZaGgr5pysg3EenxixYSbhrr5U-Xlx2nc&export=download) *(~21.4 MB - Siap Pakai)*
   - Atau salin link download langsung:
     ```text
     https://drive.usercontent.google.com/download?id=1ZaGgr5pysg3EenxixYSbhrr5U-Xlx2nc&export=download
     ```
2. Klik ganda pada file `ManggaPOS_Setup_v1.0.15.exe`. Jika muncul peringatan keamanan *Windows SmartScreen*, klik **More info** -> **Run anyway**.
3. Pilih lokasi instalasi (default: `C:\Program Files\Mangga POS` atau folder pengguna).
4. Di halaman **Select Additional Tasks**:
   - Centang **"Buat shortcut di Desktop"** untuk mempermudah akses kasir.
   - Centang **"Pasang Driver Printer Thermal Kasir (POS-58 & POS-80 USB)"** jika Anda menggunakan printer kasir USB.
5. Klik **Install** dan tunggu beberapa detik hingga proses selesai.
6. Klik **Finish**. Aplikasi Mangga POS akan otomatis terbuka dan siap digunakan!

---

## 3. Panduan Pemasangan Driver Printer Thermal USB (POS-58 & POS-80)

Aplikasi Mangga POS di Windows menggunakan layanan cetak sistem operasi (*Windows Print Spooler*). Agar printer kasir Anda terdeteksi dengan nama yang jelas, ikuti langkah berikut:

### Langkah A: Menghubungkan Printer
1. Sambungkan kabel power printer thermal ke stopkontak.
2. Hubungkan kabel USB printer ke salah satu port USB di komputer/laptop kasir.
3. Masukkan gulungan kertas struk (58mm atau 80mm) menghadap ke atas.
4. Tekan tombol **Power** printer hingga lampu indikator menyala hijau/biru.

### Langkah B: Menjalankan Installer Driver
Driver universal sudah terpasang di folder instalasi:
- **Lokasi file**: `C:\Program Files\Mangga POS\drivers\POSPrinterDriverSetup.exe`  
  *(Atau dapat diakses melalui Start Menu: **Mangga POS -> Driver Printer Thermal**)*

1. Jalankan **`POSPrinterDriverSetup.exe`**.
2. Pilih Versi OS: **Windows 10** atau **Windows 11**.
3. Pilih Jenis Printer:
   - Pilih **POS-58** jika menggunakan kertas ukuran kecil (lebar 58mm).
   - Pilih **POS-80** jika menggunakan kertas ukuran standar restoran/swalayan (lebar 80mm).
4. Pilih Port Printer:
   - Pilih **USB001** (atau USB002 jika USB001 sudah dipakai perangkat lain).
5. Klik **Install Now**.
6. Printer Anda sekarang telah terdaftar resmi di Windows sebagai printer bernama `POS-58` atau `POS-80`.

---

## 4. Konfigurasi Printer di Mangga POS

1. Buka aplikasi **Mangga POS**.
2. Masuk ke menu **Pengaturan** (ikon gear di sidebar kiri) -> **Pengaturan Printer**.
3. Pada bagian **Printer Windows / USB Terdeteksi**, sistem akan otomatis menampilkan printer Anda (misal: `POS-58` atau `POS-80`).
4. Klik pada nama printer tersebut untuk mengaktifkannya sebagai printer kasir utama.
5. Tentukan ukuran kertas: **58mm** atau **80mm**.
6. Tekan tombol **Test Print**. Printer kasir akan mengeluarkan struk uji coba bertuliskan *"Test Print Sukses"*.

> **Tips Cetak Cepat**: Setelah printer dipilih, setiap kali kasir menyelesaikan transaksi, struk dapat dicetak langsung 1-klik tanpa perlu dialog konfirmasi tambahan.

---

## 5. Fitur Unggulan Desktop: Master-Detail (Split View / Side Panel)

Pada layar lebar Windows PC / Laptop ($\ge$ 1000px), Mangga POS otomatis bertransformasi ke antarmuka **Studio Split-View**:

| Modul | Sisi Kiri (Master List) | Panel Samping Kanan (Detail Panel) |
|---|---|---|
| **Riwayat Transaksi** | Daftar invoice transaksi dengan badge status & Kasbon. | Detail lengkap belanja, metode pembayaran, audit log, dan tombol Cetak Ulang Struk / Refund. |
| **Kelola Order & Pesanan** | Tab pesanan aktif (Dine In, Takeaway, Delivery). | Rincian pesanan pelanggan dan tombol cepat **"Muat ke Kasir untuk Bayar"**. |
| **Katalog Produk** | Grid/List produk dengan filter kategori & pencarian kilat. | Panel preview produk, barcode scanner, stok outlet, dan tombol edit kilat. |
| **Arus Kas & Shift** | Laci Kas & Tabel mutasi petty cash serta riwayat tutup shift. | Detail rekonsiliasi kas (modal awal, kas sistem, kas fisik, selisih) & zoom foto bukti nota pengeluaran. |
| **Sesi Meja (Resto)** | Denah meja makan & pesanan masuk waiter / QR. | Rincian pesanan meja aktif & tombol 1-klik **"Proses Pembayaran di Kasir"**. |
| **Buku Kasbon & Pelanggan** | Daftar piutang kasbon & kontak pelanggan toko. | Progress bar pelunasan, riwayat cicilan, tombol **"Bayar Cicilan / Lunasi"**, & tombol **"Tagih via WhatsApp"**. |

---

## 6. Pertanyaan yang Sering Diajukan (FAQ Windows)

#### Q: Apakah Mangga POS di Windows memerlukan koneksi internet terus-menerus?
**A:** Tidak. Mangga POS dirancang dengan arsitektur *Offline-First*. Transaksi penjualan kasir, scan barcode, dan cetak struk tetap berjalan normal saat internet mati. Saat koneksi kembali aktif, data otomatis tersinkronisasi ke Cloud.

#### Q: Bagaimana cara backup data di Windows?
**A:** Semua data toko otomatis tersimpan aman di Cloud database terenkripsi (Supabase) dan di-cache secara lokal menggunakan SQLite. Anda juga dapat mengekspor laporan penjualan ke format **Excel (.xlsx)** kapan saja melalui menu **Laporan**.

#### Q: Bagaimana jika saya ingin update ke versi aplikasi terbaru?
**A:** Cukup jalankan file installer versi terbaru (`ManggaPOS_Setup_vX.X.X.exe`). Installer akan otomatis memperbarui aplikasi tanpa menghapus pengaturan printer maupun data lokal Anda.

---

### Bantuan & Layanan Konsultasi
Jika Anda memerlukan bantuan konfigurasi printer USB, jaringan LAN dapur, atau barcode scanner di PC kasir:
- **WhatsApp Support**: [0856-2427-7920](https://wa.me/6285624277920)
- **Website Resmi**: [https://pos.mudahkan.online](https://pos.mudahkan.online)
- **Buku Panduan Online**: [https://pos.mudahkan.online/panduan](https://pos.mudahkan.online/panduan)
