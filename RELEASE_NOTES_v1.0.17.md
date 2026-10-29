# Release Notes - Mangga POS v1.0.17 (Build 28)

**File Bundle:** [app-release.aab](file:///Users/diyanto/dpos/build/app/outputs/bundle/release/app-release.aab) (Ukuran: 77.7 MB)  
**Portal Web Merchant:** [https://app.mudahkan.online](https://app.mudahkan.online)  
**Toko Online Pelanggan:** [https://pos.mudahkan.online](https://pos.mudahkan.online)  

---

### 🚀 Google Play Console (Siap Copy-Paste / XML Tags Resmi)
*Format XML di bawah ini dapat langsung di-paste ke Google Play Console (keduanya di bawah batas maksimal 500 karakter Play Store):*

```xml
<id-ID>
• Real-Time Shift Aktif: Transaksi kasir langsung muncul seketika saat shift sedang berjalan.
• Sinkronisasi Refund Laci: Pengembalian dana tunai otomatis dicatat ke Mutasi Kas Keluar.
• Privasi Shift Kasir: Kasir hanya melihat riwayat shift miliknya, Owner memantau semua kasir.
• Akurasi Kas Laci: Penyesuaian zona waktu presisi antara laci offline dan Cloud Supabase.
• Peningkatan performa dan kestabilan aplikasi.
</id-ID>
<en-US>
• Live Active Shift: Real-time order tracking while cashier shifts are actively running.
• Cash Drawer Refund Sync: Cash refunds now automatically record as Cash Out mutations.
• Shift Privacy by Role: Cashiers view their own shifts; Owners can monitor all cashiers.
• Cash Drawer Accuracy: Accurate timezone sync between offline storage and Supabase Cloud.
• General performance & stability improvements.
</en-US>
```

---

### 🇮🇩 Bahasa Indonesia (Play Store Form Input - 425 Karakter)
```text
• Real-Time Shift Aktif: Transaksi kasir langsung muncul seketika saat shift sedang berjalan.
• Sinkronisasi Refund Laci: Pengembalian dana tunai otomatis dicatat ke Mutasi Kas Keluar.
• Privasi Shift Kasir: Kasir hanya melihat riwayat shift miliknya, Owner memantau semua kasir.
• Akurasi Kas Laci: Penyesuaian zona waktu presisi antara laci offline dan Cloud Supabase.
• Peningkatan performa dan kestabilan aplikasi.
```

---

### 🇬🇧 English (Play Store Form Input - 420 Karakter)
```text
• Live Active Shift: Real-time order tracking while cashier shifts are actively running.
• Cash Drawer Refund Sync: Cash refunds now automatically record as Cash Out mutations.
• Shift Privacy by Role: Cashiers view their own shifts; Owners can monitor all cashiers.
• Cash Drawer Accuracy: Accurate timezone sync between offline storage and Supabase Cloud.
• General performance & stability improvements.
```

---

### 📋 Rincian Pembaruan Fitur Lengkap

#### 1. ⚡ Pelacakan Transaksi Shift Berjalan Secara Real-Time
* **Langsung Muncul Seketika:** Transaksi yang dibuat kasir saat shift sedang aktif kini langsung tampil detik itu juga di tab **Rekap Kas Laci** dan tab **Transaksi**, tanpa perlu menunggu shift ditutup terlebih dahulu.
* **Perbaikan Sinkronisasi Zona Waktu (WIB vs UTC):** Menormalkan pencatatan waktu buka shift (`opened_at`) dan waktu pesanan (`created_at`) sehingga filter waktu pesanan lokal dan Supabase cloud selalu presisi.

#### 2. 💸 Pencatatan Otomatis Refund Tunai ke Mutasi Kas Keluar
* **Opsi Otomatis Saat Refund:** Di dialog pembatalan pesanan (*Void/Refund*), kasir kini diberikan konfirmasi pengeluaran uang fisik kas laci beserta opsi aktif: `[✓] Catat otomatis di Mutasi Kas Keluar Hari Ini`.
* **Kategori Pengembalian Dana:** Sistem otomatis mencatat mutasi `Kas Keluar` berkategori *Pengembalian Dana / Refund* lengkap dengan nomor invoice dan alasan pembatalan.
* **Kalkulasi Laci Seimbang (Tanpa Double Deduction):** Perhitungan kas laci diselaraskan secara akurat sehingga saldo laci kasir tetap cocok pas saat tutup shift.

#### 3. 🛡️ Pembatasan Hak Akses Riwayat Shift Berbasis Role
* **Role Kasir / Staff:** Demi privasi dan keamanan kasir, kasir hanya dapat melihat riwayat sesi shift miliknya sendiri yang pernah dia buka dan tutup. Kasir tidak dapat melihat riwayat atau selisih uang kasir lain.
* **Role Owner / Admin:** Owner dan Admin memiliki akses menyeluruh untuk memantau rekap sesi shift dari semua kasir di seluruh outlet bisnis.

#### 4. ☁️ Sinkronisasi Offline & Supabase Cloud Sempurna
* **Penyimpanan Ganda (Local SQLite + Cloud):** Transaksi tetap tersimpan aman di SQLite lokal meski tanpa internet dan otomatis tersinkronisasi ke Cloud Supabase saat koneksi kembali normal.
* **Skema Fleksibel:** Penanganan auto-fallback schema untuk atribut transaksi sehingga sinkronisasi cloud selalu berhasil tanpa error.
