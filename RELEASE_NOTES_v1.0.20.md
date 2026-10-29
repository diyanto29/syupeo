# Release Notes - Mangga POS v1.0.20 (Build 31)

**Tanggal Rilis:** 29 Oktober 2026  
**Versi Aplikasi:** 1.0.20  
**Build Number:** 31  
**Package ID:** `online.mudahkan.manggapos`  
**Target:** Google Play Console (Android App Bundle - `.aab`) & Production Deployment  
**Lokasi File AAB:** [build/app/outputs/bundle/release/app-release.aab](file:///Users/diyanto/dpos/build/app/outputs/bundle/release/app-release.aab) *(Ukuran: 78.3 MB)*  
**Portal Web Merchant:** [https://app.mudahkan.online](https://app.mudahkan.online)  
**Toko Online & Panduan:** [https://pos.mudahkan.online](https://pos.mudahkan.online)  

---

### 🚀 Google Play Console (Siap Copy-Paste / XML Tags Resmi)
*Format XML di bawah ini dapat langsung di-paste ke Google Play Console (keduanya sudah di bawah batas maksimal 500 karakter Play Store):*

```xml
<id-ID>
• Virtual Soundbox: HP bersuara otomatis saat transfer QRIS masuk (Livin, BCA, GoPay, OVO, Shopee, Dana).
• QRIS Dinamis: Barcode kasir otomatis terkunci nominal tagihan (anti-salah ketik).
• Multi-Device Relay: Notifikasi m-banking di HP Owner diteruskan instan ke kasir via cloud.
• Layanan Latar Belakang 24/7: Gateway tetap aktif membaca mutasi walau layar mati.
• Cetak Tiket Dapur: Cetak ulang pesanan koki (KOT) langsung dari Riwayat Transaksi.
• Peningkatan stabilitas kasir.
</id-ID>
<en-US>
• Virtual Soundbox: Auto voice alert on incoming QRIS payments (no soundbox hardware needed).
• Dynamic QRIS: Auto-embed bill amount into QR code for mistake-free checkout.
• Multi-Device Relay: Instantly sync Owner's payment notifications to cashier via cloud.
• 24/7 Background Service: Keeps payment gateway alive even when screen is locked.
• Kitchen Ticket Reprint: Reprint kitchen orders (KOT) anytime from Transaction History.
• Stability & cashier fixes.
</en-US>
```

---

### 🇮🇩 Bahasa Indonesia (Play Store Form Input - 468 Karakter)
```text
• Virtual Soundbox: HP bersuara otomatis saat transfer QRIS masuk (Livin, BCA, GoPay, OVO, Shopee, Dana).
• QRIS Dinamis: Barcode kasir otomatis terkunci nominal tagihan (anti-salah ketik).
• Multi-Device Relay: Notifikasi m-banking di HP Owner diteruskan instan ke kasir via cloud.
• Layanan Latar Belakang 24/7: Gateway tetap aktif membaca mutasi walau layar mati.
• Cetak Tiket Dapur: Cetak ulang pesanan koki (KOT) langsung dari Riwayat Transaksi.
• Peningkatan stabilitas kasir.
```

---

### 🇬🇧 English (Play Store Form Input - 482 Karakter)
```text
• Virtual Soundbox: Auto voice alert on incoming QRIS payments (no soundbox hardware needed).
• Dynamic QRIS: Auto-embed bill amount into QR code for mistake-free checkout.
• Multi-Device Relay: Instantly sync Owner's payment notifications to cashier via cloud.
• 24/7 Background Service: Keeps payment gateway alive even when screen is locked.
• Kitchen Ticket Reprint: Reprint kitchen orders (KOT) anytime from Transaction History.
• Stability & cashier fixes.
```

---

### 📋 Rincian Pembaruan Fitur Lengkap (v1.0.20)

#### 1. 🔊 Virtual Soundbox & Suara Text-to-Speech Kasir
* **Nol Biaya Hardware:** Tidak perlu lagi membeli atau menyewa perangkat speaker soundbox fisik jutaan rupiah dari bank. Speaker smartphone kasir/owner akan otomatis mengucapkan nominal uang yang masuk: *"Pembayaran QRIS sebesar Rp 25.000 telah diterima"*.
* **Pengaturan Kecepatan Bicara (Slider 0.35x - 0.70x):** Pelafalan nominal kini terdengar tenang, jelas, dan ramah di telinga kasir.
* **Tombol Uji Coba Audio:** Tersedia tombol simulasi suara langsung di menu pengaturan untuk memeriksa output speaker HP.

#### 2. 📱 QRIS Dinamis Otomatis Nominal Tagihan
* **Semat Nominal Otomatis:** Saat kasir memilih pembayaran QRIS, sistem men-generate barcode QR dinamis dengan nominal tagihan belanjaan yang sudah terkunci.
* **Anti-Salah Nominal:** Pembeli tidak perlu lagi mengetik nominal manual di m-banking/e-wallet mereka, mencegah salah transfer atau kecurangan.
* **Upload QRIS dari Galeri:** Pemilik toko dapat langsung memilih foto QRIS merchant resmi dari galeri foto HP tanpa repot scan manual.

#### 3. ☁️ Multi-Device Payment Relay (Mode Gateway HP Owner ➔ Tablet Kasir)
* **Sinkronisasi Antar Perangkat:** Notifikasi pembayaran m-banking yang masuk ke HP pribadi Owner (Livin' Merchant Bank Mandiri, BCA Merchant, GoBiz, OVO, ShopeePay, Dana) seketika diteruskan ke tablet kasir di meja kasir.
* **Dual Delivery Cloud:** Data pembayaran dikirim via Supabase Realtime sekaligus disimpan persisten di cloud database terenkripsi RLS multi-outlet.
* **Anti-Terlewat (Catch-Up Query):** Jika pembeli transfer sebelum kasir membuka jendela QR atau saat sinyal sempat putus, transaksi otomatis terverifikasi seketika kasir membuka jendela QR.

#### 4. 🛡️ Layanan Latar Belakang 24 Jam Nonstop (Android Foreground Service)
* **Notifikasi Status Bar Persisten:** Ikon *"Mangga POS Payment Gateway Aktif"* siaga menjaga service tetap berjalan di latar belakang Android walau HP terkunci di saku.
* **Tombol Bypass Pengoptimalan Baterai:** Tombol langsung di pengaturan untuk mematikan mode hemat daya (Doze Mode) sistem Android.

#### 5. 🍳 Cetak Ulang Tiket Dapur (KOT) di Riwayat Transaksi
* **Solusi Meja & Dapur Resto:** Jika kertas pesanan dapur koki hilang atau basah, kasir atau owner dapat mencetak ulang tiket pesanan (KOT) langsung dari arsip Riwayat Transaksi.

#### 6. 🛒 Perbaikan Transaksi & Pengalaman Pengguna
* **Auto-Close Keranjang:** Layar keranjang mobile otomatis tertutup setelah transaksi berhasil diselesaikan.
* **Reset Saving State:** Tombol checkout tidak lagi macet jika terjadi gangguan koneksi sesaat.
