# Release Notes - Mangga POS (v1.0.20+31)

**Tanggal Rilis:** 29 Oktober 2026  
**Versi Aplikasi:** 1.0.20  
**Build Number:** 31  
**Target:** Google Play Console (Android App Bundle - `.aab`) & Production Deployment  
**Lokasi File AAB:** [build/app/outputs/bundle/release/app-release.aab](file:///Users/diyanto/dpos/build/app/outputs/bundle/release/app-release.aab) *(Ukuran: 78.3 MB)*  
**Package ID:** `online.mudahkan.manggapos`  
**Target Platform:** Android (HP & Tablet), Windows (PC/Laptop), & Web Browser (`app.mudahkan.online`)  

---

## 🚀 Apa yang Baru di Rilis v1.0.20 (Build 31)

### 1. 🔊 Virtual Soundbox & Notifikasi Suara TTS (Nol Biaya Hardware)
- **Pengumuman Suara Otomatis:** Speaker smartphone otomatis mengumumkan uang masuk begitu transfer QRIS terverifikasi (misal: *"Pembayaran QRIS sebesar Rp 25.000 telah diterima"*).
- **Pengaturan Kecepatan Suara:** Slider tempo pelafalan (0.35x - 0.70x) dengan tombol uji coba suara di menu pengaturan agar suara terdengar jelas dan ramah bagi kasir.

### 2. 📱 QRIS Dinamis Otomatis Nominal Tagihan
- **Semat Nominal Otomatis:** Pop-up QRIS kasir langsung mengunci nominal total belanjaan pelanggan sehingga pembeli tidak perlu mengetik nominal manual di m-banking.
- **Upload Gambar QRIS Toko:** Pemilik toko dapat langsung memilih foto QRIS merchant dari galeri foto HP tanpa scan manual.

### 3. ☁️ Multi-Device Payment Relay Cloud 24/7
- **Mode Gateway HP Owner:** Notifikasi pembayaran dari Livin' Merchant Bank Mandiri, BCA Merchant, GoBiz (GoPay), ShopeePay, OVO, dan Dana di HP Owner seketika diteruskan ke tablet kasir.
- **Dual Delivery Cloud:** Data pembayaran tersimpan persisten di Supabase database terlindungi RLS + siaran Realtime Broadcast.
- **Catch-Up Query Otomatis:** Layar kasir langsung otomatis terverifikasi seketika membuka QR bahkan jika pembeli transfer sebelum modal dibuka atau sinyal sempat putus.

### 4. 🛡️ Layanan Latar Belakang 24 Jam Nonstop (Android Foreground Service)
- **Status Bar Icon Persisten:** Ikon *"Mangga POS Payment Gateway Aktif"* siaga menjaga service tetap aktif saat layar HP mati atau aplikasi diminimize.
- **Bebas Batasan Baterai:** Tombol izin langsung di pengaturan untuk mematikan mode pengoptimalan baterai Android.

### 5. 🍳 Cetak Ulang Tiket Dapur (KOT) di Riwayat Transaksi
- **Tiket Dapur dari Riwayat:** Kasir/owner dapat mencetak ulang tiket pesanan koki (KOT) kapan saja dari arsip Riwayat Transaksi jika kertas pesanan dapur hilang atau rusak.

### 6. 🛒 Peningkatan Stabilitas Transaksi & Kasir
- **Auto-Close Keranjang:** Layar keranjang smartphone otomatis tertutup begitu alert sukses transaksi ditutup.
- **Reset Saving State:** Memastikan tombol checkout kasir dapat diklik ulang jika terjadi gangguan jaringan sesaat.

---

## 📋 Teks Siap Pakai untuk Google Play Console (What's New)

### A. Format Multi-Bahasa (XML Tags Google Play Console):
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

### B. Bahasa Indonesia (Play Store Form Input - 468 Karakter)
```text
• Virtual Soundbox: HP bersuara otomatis saat transfer QRIS masuk (Livin, BCA, GoPay, OVO, Shopee, Dana).
• QRIS Dinamis: Barcode kasir otomatis terkunci nominal tagihan (anti-salah ketik).
• Multi-Device Relay: Notifikasi m-banking di HP Owner diteruskan instan ke kasir via cloud.
• Layanan Latar Belakang 24/7: Gateway tetap aktif membaca mutasi walau layar mati.
• Cetak Tiket Dapur: Cetak ulang pesanan koki (KOT) langsung dari Riwayat Transaksi.
• Peningkatan stabilitas kasir.
```

### C. English (Play Store Form Input - 482 Karakter)
```text
• Virtual Soundbox: Auto voice alert on incoming QRIS payments (no soundbox hardware needed).
• Dynamic QRIS: Auto-embed bill amount into QR code for mistake-free checkout.
• Multi-Device Relay: Instantly sync Owner's payment notifications to cashier via cloud.
• 24/7 Background Service: Keeps payment gateway alive even when screen is locked.
• Kitchen Ticket Reprint: Reprint kitchen orders (KOT) anytime from Transaction History.
• Stability & cashier fixes.
```
