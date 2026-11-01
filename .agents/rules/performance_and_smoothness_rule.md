# Aturan Performa, Efisiensi Memori & Kelancaran UI (Smoothness) di Syupeo

Aplikasi POS sering dijalankan pada perangkat Android spesifikasi rendah (entry-level POS terminal dengan RAM 2GB-3GB). Aturan performa ini wajib dipatuhi untuk menjaga kecepatan respon 60 FPS dan mencegah aplikasi lag atau crash.

---

## 1. Kompresi & Manajemen Gambar Produk

1. **Batas Ukuran Upload Gambar:**
   - Foto produk yang diunggah ke Supabase Storage **WAJIB dikompresi** terlebih dahulu melalui `ProductImageCompressionHelper`:
     - Maksimum resolusi: **640 × 640 px**
     - Kualitas JPEG: **75-80%**
     - Ukuran file maksimal: **<= 70 KB**
   - Menghindari pemborosan kuota penyimpanan Supabase dan mempercepat loading katalog di perangkat kasir.
2. **Penggunaan `CachedNetworkImage`:**
   - Semua gambar produk dari network wajib menggunakan `CachedNetworkImage` dengan konfigurasi `memCacheWidth: 300` dan placeholder skeleton/shimmer:
     ```dart
     CachedNetworkImage(
       imageUrl: product.imageUrl,
       memCacheWidth: 300,
       fit: BoxFit.cover,
       placeholder: (context, url) => Container(color: Colors.grey.shade100),
       errorWidget: (context, url, error) => const Icon(Icons.broken_image),
     )
     ```

---

## 2. Optimasi Render Flutter & Widget Tree

1. **Wajib Menggunakan Konstruktor `const`:**
   - Pasang kata kunci `const` pada seluruh widget yang tidak memiliki properti dinamis untuk mencegah garbage collection churn dan rebuild sia-sia.
2. **Pisahkan Widget Kompleks Menjadi Widget Kecil Mandiri:**
   - Hindari membuat method `Widget _buildItem()` di dalam State class karena akan merender ulang seluruh komponen saat `setState()` dipanggil.
   - Buat class StatelessWidget mandiri (`ProductCard`, `CartItemRow`) agar engine Flutter dapat melakukan *element tree diffing* yang efisien.
3. **Gunakan `ListView.builder` dan `GridView.builder`:**
   - Dilarang merender daftar panjang menggunakan `Column(children: list.map(...))` karena semua elemen akan langsung dirender ke memori secara bersamaan.
   - Selalu gunakan `builder` virtualized view dengan properti `itemExtent` jika tinggi item seragam.

---

## 3. Operasi I/O Hardware & Cetak Non-Blocking

1. **Pencetakan Bluetooth Asynchronous:**
   - Pengiriman byte ESC/POS ke printer thermal harus dibungkus dalam `Future` background agar animasi loading atau pergantian layar checkout tidak mengalami micro-stutter (lag).
2. **Scanner Barcode:**
   - Pada `MobileScanner`, pause controller (`cameraController.stop()`) ketika bottom sheet atau dialog checkout terbuka, dan resume kembali hanya saat kasir kembali ke layar pemindaian untuk menghemat baterai dan konsumsi CPU.
