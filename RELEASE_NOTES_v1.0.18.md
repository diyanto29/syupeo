# Release Notes - Mangga POS v1.0.18 (Build 29)

**File Bundle:** [app-release.aab](file:///Users/diyanto/dpos/build/app/outputs/bundle/release/app-release.aab) (Ukuran: 77.9 MB)  
**Portal Web Merchant:** [https://app.mudahkan.online](https://app.mudahkan.online)  
**Toko Online Pelanggan:** [https://pos.mudahkan.online](https://pos.mudahkan.online)  

---

### 🚀 Google Play Console (Siap Copy-Paste / XML Tags Resmi)
*Format XML di bawah ini dapat langsung di-paste ke Google Play Console (keduanya di bawah batas maksimal 500 karakter Play Store):*

```xml
<id-ID>
• Kitchen Display System (KDS): Antrian pesanan dapur real-time dengan timer SLA & alur status masak.
• Integrasi Kasir-Dapur: Kirim pesanan ke dapur, cetak KOT, & bayar langsung pesanan yang sudah siap.
• Resep BOM & Stock Opname FnB: Audit stok bahan baku massal & analisis selisih kerugian (Food Loss).
• Tampilan Responsif HP & Tablet: Desain bersih, bebas overflow, dan kartu menu inventori lebih lega.
• Peningkatan performa & kestabilan aplikasi.
</id-ID>
<en-US>
• Kitchen Display System (KDS): Live kitchen queue with SLA visual timers & cooking workflow.
• POS-Kitchen Integration: Send orders to kitchen, print KOT, & instant payment for served orders.
• Recipe BOM & FnB Stock Opname: Bulk raw material audits & food loss variance analytics.
• Responsive Tablet & Mobile UI: Clean layout, 0 pixel overflow, & unconstrained inventory action cards.
• General performance & stability improvements.
</en-US>
```

---

### 🇮🇩 Bahasa Indonesia (Play Store Form Input - 428 Karakter)
```text
• Kitchen Display System (KDS): Antrian pesanan dapur real-time dengan timer SLA & alur status masak.
• Integrasi Kasir-Dapur: Kirim pesanan ke dapur, cetak KOT, & bayar langsung pesanan yang sudah siap.
• Resep BOM & Stock Opname FnB: Audit stok bahan baku massal & analisis selisih kerugian (Food Loss).
• Tampilan Responsif HP & Tablet: Desain bersih, bebas overflow, dan kartu menu inventori lebih lega.
• Peningkatan performa & kestabilan aplikasi.
```

---

### 🇬🇧 English (Play Store Form Input - 435 Karakter)
```text
• Kitchen Display System (KDS): Live kitchen queue with SLA visual timers & cooking workflow.
• POS-Kitchen Integration: Send orders to kitchen, print KOT, & instant payment for served orders.
• Recipe BOM & FnB Stock Opname: Bulk raw material audits & food loss variance analytics.
• Responsive Tablet & Mobile UI: Clean layout, 0 pixel overflow, & unconstrained inventory action cards.
• General performance & stability improvements.
```

---

### 📋 Rincian Pembaruan Fitur Lengkap

#### 1. 🍳 Kitchen Display System (KDS) & Integrasi Dapur Real-Time
* **Antrian Dapur Interaktif:** Tampilan pesanan khusus tim dapur dengan kartu pesanan yang memuat rincian item, varian, catatan kustom, nomor meja / opsi makan (*Dine In / Take Away*).
* **Timer SLA Visual:** Indikator warna dinamis untuk mengontrol kecepatan penyajian (Hijau: Pesanan Baru, Kuning: Sedang Dimasak, Merah: Melebihi Target Waktu).
* **Alur Status Masak Instan:** Tombol *Mulai Masak* dan *Selesai / Sajikan (Served)* bekerja secara *real-time* dengan *optimistic UI* dan sinkronisasi instan ke seluruh perangkat kasir & pelayan.
* **Workspace Khusus Peran Dapur (*Kitchen Role*):** Pengguna dengan role Dapur langsung diarahkan ke layar KDS tanpa distraksi menu kasir atau laporan keuangan.

#### 2. 🧾 Alur Kasir ke Dapur Terpadu
* **Tombol "Kirim ke Dapur":** Kasir dapat mengirim pesanan *Dine In* langsung ke dapur sebelum pembayaran diselesaikan.
* **Cetak Tiket Pesanan Dapur (KOT):** Tiket pesanan dapur dapat langsung tercetak otomatis ke printer thermal dapur.
* **Pembayaran Langsung Pesanan *Served*:** Kasir dapat langsung menekan tombol bayar pada pesanan yang sudah disajikan dari riwayat atau notifikasi, tanpa perlu mencari ulang di draft.
* **Live Status Chip:** Kasir dapat melihat status pengerjaan pesanan dapur (*Menunggu*, *Dimasak*, *Siap Saji*) secara *live* langsung di kartu pesanan.

#### 3. 📦 Manajemen Inventori FnB, Resep BOM & Stock Opname
* **Lembar Audit Stock Opname Massal:** Formulir cepat untuk menghitung fisik seluruh bahan baku dan produk secara serentak tanpa perlu input satu per satu.
* **Resep Bahan Baku (BOM - Bill of Materials):** Penentuan porsi dan takaran bahan baku per varian menu dengan kalkulasi otomatis HPP (*Cost of Goods Sold* / COGS).
* **Pemotongan Otomatis Bahan Baku:** Stok bahan baku otomatis terpotong saat pesanan selesai terjual.
* **Analisis Varian Selisih (*Food Loss Analytics*):** Laporan selisih antara stok sistem vs fisik untuk mendeteksi kehilangan bahan baku, *spoilage*, atau kebocoran porsi.

#### 4. 📱 Desain Antarmuka Responsif (HP & Tablet)
* **Bebas Overflow di HP:** Mengatasi masalah *bottom overflowed by 31 pixels* pada kartu ringkasan inventori dengan penyesuaian tinggi komponen yang presisi.
* **Kartu Aksi 1-Kolom di HP:** Menu aksi cepat inventori kini tampil dalam layout satu kolom penuh (*full-width card*) sehingga judul, badge (*PO*, *FnB*, *Audit*, *BOM*), dan deskripsi terbaca utuh tanpa terpotong titik-titik.
* **Layout 2-Kolom Seimbang di Tablet:** Tampilan tablet dioptimalkan dengan pembagian grid 2 kolom yang proporsional dan elegan.

#### 5. ⚙️ Penyesuaian Fitur & Stabilitas
* **Integrasi Template Bisnis:** Fitur antrian dapur (`kitchen_kds`) telah disinkronkan secara konsisten di template bisnis dan tier paket (Free / Pro / Off).
* **Peningkatan Performa:** Optimasi query database dan *caching* lokal untuk responsivitas aplikasi yang lebih mulus.
