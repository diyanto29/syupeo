# Release Notes - Mangga POS v1.0.16 (Build 27) & Web Backoffice

**File Bundle:** [app-release.aab](file:///Users/diyanto/dpos/build/app/outputs/bundle/release/app-release.aab) (Ukuran: 74 MB)  
**Portal Web Merchant:** [https://app.mudahkan.online](https://app.mudahkan.online)  
**Toko Online Pelanggan:** [https://pos.mudahkan.online](https://pos.mudahkan.online)  

---

### 🚀 Google Play Console (Siap Copy-Paste / XML Tags Resmi)
*Format XML di bawah ini dapat langsung di-paste ke Google Play Console (keduanya di bawah batas maksimal 500 karakter Play Store):*

```xml
<id-ID>
• Lacak Transaksi Shift: Pantau seluruh riwayat struk & omzet per sesi shift kasir.
• Auto-Connect Printer: Printer thermal Bluetooth otomatis terhubung saat buka aplikasi.
• Akses Menu Pengaturan: Menu Pengaturan & Printer kini tersedia untuk Kasir & Admin.
• Tipe Order Fleksibel: Dukungan Dine In, Take Away, Delivery, dan Ojol tanpa hambatan.
• Web Backoffice: Peningkatan rincian transaksi & laporan di app.mudahkan.online.
• Peningkatan performa & stabilitas.
</id-ID>
<en-US>
• Shift Transactions: Track full order history and revenue per cashier shift.
• Auto-Connect Printer: Bluetooth thermal printers now auto-connect on app launch.
• Settings Access: Printer & settings now accessible for Cashier and Admin roles.
• Flexible Order Types: Support for Dine In, Take Away, Delivery, and Ride-Hailing.
• Web Backoffice: Improved transaction details and reports on app.mudahkan.online.
• Performance & stability enhancements.
</en-US>
```

---

### 🇮🇩 Bahasa Indonesia (Play Store Form Input - 475 Karakter)
```text
• Lacak Transaksi Shift: Pantau seluruh riwayat struk & omzet per sesi shift kasir.
• Auto-Connect Printer: Printer thermal Bluetooth otomatis terhubung saat buka aplikasi.
• Akses Menu Pengaturan: Menu Pengaturan & Printer kini tersedia untuk Kasir & Admin.
• Tipe Order Fleksibel: Dukungan Dine In, Take Away, Delivery, dan Ojol tanpa hambatan.
• Web Backoffice: Peningkatan rincian transaksi & laporan di app.mudahkan.online.
• Peningkatan performa & stabilitas.
```

---

### 🇬🇧 English (Play Store Form Input - 465 Karakter)
```text
• Shift Transactions: Track full order history and revenue per cashier shift.
• Auto-Connect Printer: Bluetooth thermal printers now auto-connect on app launch.
• Settings Access: Printer & settings now accessible for Cashier and Admin roles.
• Flexible Order Types: Support for Dine In, Take Away, Delivery, and Ride-Hailing.
• Web Backoffice: Improved transaction details and reports on app.mudahkan.online.
• Performance & stability enhancements.
```

---

### 📋 Rincian Pembaruan Fitur Lengkap

#### 1. 💼 Lacak & Riwayat Transaksi Penjualan Per Shift
* **Daftar Transaksi Langsung di Sesi Shift:** Tab khusus "Transaksi" kini disematkan di dalam setiap detail riwayat shift dan shift berjalan.
* **Filter & Pencarian Pintar:** Filter transaksi Tunai vs Non-Tunai (QRIS/Transfer/EDC) serta pencarian invoice, meja, dan nama pelanggan.
* **Ringkasan Omzet Shift:** Audit otomatis total omzet shift, perbandingan pemasukan tunai vs non-tunai, dan jumlah order.
* **Akses Struk & Cetak Ulang:** Setiap transaksi dalam shift dapat diklik langsung untuk memeriksa rincian item, diskon, dan opsi cetak ulang struk kasir.

#### 2. 🖨️ Auto-Connect Printer Thermal Bluetooth
* **Koneksi Otomatis Saat Buka Aplikasi:** Tidak perlu lagi menekan tombol "Hubungkan" secara manual setiap kali membuka aplikasi. Aplikasi secara cerdas mencoba menghubungkan ulang socket Bluetooth ke printer yang tersimpan di background.
* **Deteksi Pintar Tanpa Notifikasi Gangguan:** Jika printer berhasil terhubung otomatis, notifikasi *"Printer belum terhubung"* tidak akan muncul di layar utama kasir.
* **Auto-Reconnect di Pengaturan:** Halaman Pengaturan Printer dan pemindaian status Bluetooth otomatis mencoba koneksi ulang begitu Bluetooth perangkat dinyalakan.

#### 3. 👥 Akses Menu Pengaturan & Printer untuk Semua Role
* **Role Kasir & Admin:** Menu **Pengaturan** dan **Pengaturan Printer** kini dapat diakses langsung dari sidebar/drawer oleh kasir dan admin untuk memudahkan setup printer struk.
* **Role Waiter & Dapur:** Pengelompokan seksi menu diperjelas dan dilengkapi akses pengaturan printer untuk kebutuhan cetak tiket pesanan dapur.
* **Tampilan Tablet Landscape:** Pada layar tablet dengan sidebar terkunci (pinned), menu Pengaturan Printer terbuka langsung di area konten utama tanpa menutupi sidebar navigasi.

#### 4. 🍽️ Konfigurasi Tipe Order Kasir yang Fleksibel
* **Transaksi Tetap Berjalan Lancar:** Sistem memiliki mekanisme fallback aman ke default (`Makan di Tempat` / `dine_in`), memastikan kasir dapat langsung transaksi tanpa terhambat setting tipe order.
* **Opsi Lengkap:** Dukungan kustomisasi biaya tambahan (surcharge), ikon, dan nama tipe pesanan (Dine In, Take Away, GoFood, GrabFood, ShopeeFood, Delivery).

#### 5. 🌐 Peningkatan Web Backoffice Merchant (`app.mudahkan.online`)
* **Detail Transaksi Akurat:** Rincian harga satuan (`unit_price`), diskon, dan metode pembayaran kini tampil lengkap dan akurat di portal backoffice.
* **Deploy Produksi:** Seluruh pembaruan telah terdeploy dan aktif di production Vercel.
