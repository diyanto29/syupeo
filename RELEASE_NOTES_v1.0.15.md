# Release Notes - Mangga POS v1.0.15 (Build 26) & Web Backoffice

**File Bundle:** [app-release.aab](file:///Users/diyanto/dpos/build/app/outputs/bundle/release/app-release.aab) (Ukuran: 69 MB)  
**Portal Web Merchant:** [https://app.mudahkan.online](https://app.mudahkan.online)  
**Toko Online Pelanggan:** [https://pos.mudahkan.online](https://pos.mudahkan.online)  

---

### 🚀 Google Play Console (Siap Copy-Paste / XML Tags Resmi)
*Format XML di bawah ini dapat langsung di-paste ke Google Play Console (keduanya sudah di bawah batas maksimal 500 karakter Play Store):*

```xml
<id-ID>
• Navigasi Baru: Riwayat Transaksi kini di posisi atas untuk cetak struk & void lebih cepat.
• Kategori Menu: Tata letak drawer terstruktur (Operasional, FnB, Katalog, Pengaturan).
• Buku Kasbon & Tempo: Catat piutang, tentukan jatuh tempo, dan kirim tagihan via WhatsApp.
• Indikator Kasbon: Status tempo di struk printer thermal & nota digital.
• Toko Online: Checkout WhatsApp anti-blokir popup & otomatis masuk ke Pesanan Masuk.
• Peningkatan performa & stabilitas.
</id-ID>
<en-US>
• Faster Navigation: Transaction History moved up for instant receipt reprints & voids.
• Organized Drawer: Clean sections for Operations, FnB, Catalog, and Store Settings.
• Customer Debt & Pay-Later: Track receivables, set due dates, and send WhatsApp reminders.
• Debt Badge on Receipts: Clear pay-later status on thermal receipts & digital invoices.
• Online Store Sync: Direct WhatsApp checkout & auto-routing to cashier Incoming Orders.
• Performance & stability enhancements.
</en-US>
```

---

### 🇮🇩 Bahasa Indonesia (Play Store Form Input - 472 Karakter)
```text
• Navigasi Baru: Riwayat Transaksi kini di posisi atas untuk cetak struk & void lebih cepat.
• Kategori Menu: Tata letak drawer terstruktur (Operasional, FnB, Katalog, Pengaturan).
• Buku Kasbon & Tempo: Catat piutang, tentukan jatuh tempo, dan kirim tagihan via WhatsApp.
• Indikator Kasbon: Status tempo di struk printer thermal & nota digital.
• Toko Online: Checkout WhatsApp anti-blokir popup & otomatis masuk ke Pesanan Masuk.
• Peningkatan performa & stabilitas.
```

---

### 🇬🇧 English (Play Store Form Input - 485 Karakter)
```text
• Faster Navigation: Transaction History moved up for instant receipt reprints & voids.
• Organized Drawer: Clean sections for Operations, FnB, Catalog, and Store Settings.
• Customer Debt & Pay-Later: Track receivables, set due dates, and send WhatsApp reminders.
• Debt Badge on Receipts: Clear pay-later status on thermal receipts & digital invoices.
• Online Store Sync: Direct WhatsApp checkout & auto-routing to cashier Incoming Orders.
• Performance & stability enhancements.
```

---

### 📋 Rincian Pembaruan Fitur Lengkap

#### 1. 🗂️ Navigasi Drawer Baru & Kategori Terstruktur
* **Akses Cepat Riwayat Transaksi:** Riwayat Transaksi (`checkoutVoid`) kini dipindahkan ke urutan ke-4 (tepat di bawah Transaksi dan Pesanan Masuk). Kasir tidak perlu lagi menggulir layar ke bawah untuk mencari nota atau cetak ulang struk printer.
* **Kategori Terorganisir:** Ditambahkan pembatas bagian (`MenuSection`) yang elegan:
  - **OPERASIONAL**: Beranda, Transaksi, Pesanan & Draft, Riwayat Transaksi, Buku Kasbon, Arus Kas & Shift.
  - **RESTO & MEJA**: Sesi Meja, Antrian Dapur (KDS), QR Self-Order *(otomatis sesuai paket resto)*.
  - **KATALOG & LAPORAN**: Produk & Diskon, Inventori / Stok, Laporan Penjualan, Asisten AI.
  - **PENGATURAN TOKO**: Staf & Hak Akses, Outlet, Profil Bisnis, Pengaturan Sistem, Langganan, dan Bantuan.

#### 2. 📖 Buku Kasbon & Pembayaran Tempo (Piutang Pelanggan)
* **Manajemen Piutang:** Catat hutang belanja pelanggan langsung saat checkout transaksi atau melalui menu Buku Kasbon.
* **Jatuh Tempo & Tagihan WhatsApp:** Tentukan tanggal jatuh tempo dan kirim rincian nota tagihan langsung ke nomor WhatsApp pelanggan dengan satu ketukan.
* **Badge Status:** Struk fisik thermal Bluetooth dan nota digital kini menyertakan informasi status pembayaran Tempo/Kasbon secara jelas.

#### 3. 🌐 Sinkronisasi Toko Online (`/s/:slug`) & Pesanan Masuk POS
* **Direct Navigation WhatsApp:** Menghilangkan masalah *popup blocker* pada peramban mobile (Chrome/Safari) saat checkout order online.
* **Multi-Outlet Smart Routing:** Pesanan dari toko online secara cerdas diarahkan ke outlet utama (`code: 'main'`) atau outlet aktif beroperasi, sehingga langsung muncul di tab **Pesanan Masuk** kasir.
