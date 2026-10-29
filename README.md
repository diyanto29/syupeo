# dpos

Prototype Flutter untuk sistem Point of Sale multi-role berbasis aplikasi mobile:

- `Waiter`: buka meja, validasi order QR, input order manual, notifikasi layanan.
- `Customer`: scan QR session aktif dari app mobile, browsing menu, filter kategori, order tracking, call waiter.
- `Kitchen`: antrian KDS FIFO, priority label, grouping item, toggle stok.
- `Admin / Kasir`: checkout akhir, kill switch session, analytics singkat, user management.

## Status Saat Ini

Project ini sudah punya MVP frontend mobile berbasis data dummy/in-memory untuk memvisualisasikan requirement utama tanpa backend.

## Menjalankan Project

```bash
flutter pub get
flutter run -d android
```

## Konfigurasi Supabase

Project ini sudah disiapkan untuk bootstrap Supabase dari `--dart-define`.

```bash
flutter run -d android \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

Kalau dua value itu belum diisi, app tetap jalan tetapi masih memakai data dummy/in-memory.

Untuk `Google Sign-In + supabase.auth.signInWithIdToken(...)`, `GOOGLE_WEB_CLIENT_ID`
wajib diisi dengan `Web application client ID` dari Google Cloud Console.
Khusus Android release, tambahkan juga `SHA-1` dan `SHA-256` dari keystore release
ke Firebase Console pada app Android `online.mudahkan.dpos`, lalu download ulang
`android/app/google-services.json`. Kalau fingerprint release belum terdaftar,
login Google di APK release biasanya gagal dengan `ApiException: 10`.

Kalau target iOS, tambahkan juga:

```bash
--dart-define=GOOGLE_IOS_CLIENT_ID=YOUR_IOS_CLIENT_ID.apps.googleusercontent.com
```

## Langkah Berikutnya

- Sambungkan state ke `Supabase` untuk auth, session table, order realtime, dan inventory.
- Pisahkan app per role jika nanti mau dibuat `waiter mobile`, `customer mobile`, `kitchen tablet`, dan `admin mobile`.
- Tambahkan printer integration, QR generator/scanner, dan export laporan ke Excel/PDF.
