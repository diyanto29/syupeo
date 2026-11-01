# Aturan Desain Responsif & Tata Letak Tablet / Desktop di Syupeo

Aplikasi **Syupeo** berjalan pada beragam form-factor: Smartphone Android, Tablet POS kasir (landscape/portrait), serta Desktop Windows/macOS. Aturan ini memastikan tata letak selalu konsisten dan bebas dari `RenderFlex overflow`.

---

## 1. Deteksi Perangkat & Breakpoint

Gunakan helper orientasi atau lebar layar untuk menentukan mode tampilan:

```dart
final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
```

---

## 2. Pola Layar Kasir POS Tablet vs Smartphone

1. **Smartphone (Mobile View - Single Column):**
   - Katalog produk tampil satu layar penuh (Grid 2-3 kolom).
   - Keranjang kasir disajikan melalui Bottom Sheet mengambang atau bar bawah yang dapat di-tap untuk membuka checkout.
2. **Tablet & Desktop (Split View 2-Kolom):**
   - Kolom Kiri (~60-65% lebar layar): Katalog produk, filter kategori, dan pencarian cepat / barcode scanner.
   - Kolom Kanan (~35-40% lebar layar): Panel keranjang kasir permanen, daftar pesanan aktif, kalkulasi subtotal/pajak/diskon, dan tombol "Bayar Sekarang" tanpa perlu membuka modal tambahan.
   - Lihat implementasi referensi di `lib/features/product_catalog/presentation/views/product_dashboard_tablet.dart` vs `product_dashboard_mobile.dart`.

---

## 3. Pencegahan `RenderFlex Overflow`

1. **Gunakan `Expanded` & `Flexible` dengan Tepat:**
   - Dalam `Row` atau `Column`, selalu bungkus teks dinamis (seperti nama produk panjang atau harga) dengan `Expanded` dan set `maxLines: 2, overflow: TextOverflow.ellipsis`.
2. **Bungkus Formulir dengan `SingleChildScrollView`:**
   - Setiap layar yang memiliki `TextField` wajib dibungkus `SingleChildScrollView` atau `ListView` dengan `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag` agar tidak overflow saat keyboard virtual muncul.
3. **Ukuran Dialog & Bottom Sheet:**
   - Batasi lebar maksimum dialog pada tablet/desktop:
     ```dart
     ConstrainedBox(
       constraints: const BoxConstraints(maxWidth: 480),
       child: ...
     )
     ```
