# Syupeo — Retail & POS Partnership Platform

Sistem Point of Sale (POS) & Platform Kemitraan Toko Ritel Modern berbasis Flutter Mobile/Tablet dan Next.js Web Admin.

- `Owner / Mitra`: Setup toko ritel, geofencing lokasi, pemesanan Paket Usaha (Starter Kits), kulakan, dan laporan omzet real-time.
- `Kasir`: POS checkout kilat, scan barcode, cetak struk Bluetooth ESC/POS (58mm/80mm), pembayaran tunai & QRIS dinamis.
- `Kitchen / KDS`: Antrian pesanan FIFO, label prioritas, dan pembaruan status stok.
- `Pelanggan`: Akses menu & katalog online, pemesanan mandiri, dan integrasi WhatsApp.

## Menjalankan Mobile App (Flutter)

```bash
flutter pub get
flutter run -d android
```

## Konfigurasi Supabase

Aplikasi berjalan dengan backend Supabase:

```bash
flutter run -d android \
  --dart-define=SUPABASE_URL=https://fgzmwmtssrviptflsjqy.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=GOOGLE_WEB_CLIENT_ID=384714806025-kiscrufjnkd5i603irmcjff2lmfa72ik.apps.googleusercontent.com
```

Untuk Android, package resmi adalah `online.mudahkan.syupeo` dengan keystore `android/app/syupeo-release.jks`.
