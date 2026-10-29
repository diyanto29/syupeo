# 📈 Simulasi Titik Impas (BEP), Laba/Rugi, & Proyeksi Arus Kas SaaS POS
**Mangga POS (Point of Sales)**  
*Dokumen Analisis Finansial, Unit Economics, Proyeksi Transisi Server Free ke Berbayar, dan Komisi Mitra (20%)*

---

## 📌 1. Ringkasan Eksekutif (Key Metrics)

| Metrik Finansial | Opsi A: VPS Self-Hosted 🏆 | Opsi B: Supabase Cloud Pro |
| :--- | :---: | :---: |
| **Biaya Operasional Tetap (Fixed OpEx)** | **~Rp 170.000 / bulan** | **~Rp 500.000 / bulan** |
| **BEP Toko (Organik Tanpa Mitra)** | **12 Toko** | **34 Toko** |
| **BEP Toko (Bauran 50% Mitra / 50% Organik)** ⭐ | **13 Toko** | **38 Toko** |
| **BEP Toko (100% Toko dari Mitra - Potongan 20%)** | **15 Toko** | **42 Toko** |
| **Kas Bersih Masuk dari 10 Toko Pertama (Mitra 20%)** | **Rp 1.440.000** (Cukup 8,5 bulan VPS) | **Rp 1.440.000** (Cukup 2,8 bulan server) |
| **Laba Bersih pada 100 Toko (Bauran Mitra 50%)** | **+Rp 1.180.000 / bulan** | **+Rp 850.000 / bulan** |
| **Laba Bersih pada 500 Toko (Bauran Mitra 50%)** | **+Rp 6.400.000 / bulan** | **+Rp 6.050.000 / bulan** |

---

## 🤝 2. Skema Pembagian Hasil dengan Mitra (Rev-Share 20%)

Mangga POS memiliki modul kemitraan (*partner referral*). Mitra berperan sebagai tim penjualan lapangan, mengedukasi pedagang, dan membantu setup perangkat kasir/printer di toko merchant.

```
┌────────────────────────────────────────────────────────────────────────┐
│             DISTRIBUSI PEMBAYARAN DARI MERCHANT (PAKET 1 TAHUN)         │
├────────────────────────────────────────────────────────────────────────┤
│ Total Bayar Merchant: Rp 180.000 / tahun                               │
│  ├── 20% Hak Mitra   : Rp 36.000 / tahun (Komisi Sukses Closing)       │
│  └── 80% Net Developer: Rp 144.000 / tahun (Rp 12.000 / toko / bulan)  │
└────────────────────────────────────────────────────────────────────────┘
```

### Breakdown Komisi Mitra & Net Pengembang per Paket:
| Durasi Paket | Harga Langganan Toko | Komisi Mitra (20%) | Net Bersih Pengembang (80%) | Net Pengembang / Bulan |
| :--- | :---: | :---: | :---: | :---: |
| **1 Tahun (Flagship)** | **Rp 180.000** | **Rp 36.000** | **Rp 144.000** | **Rp 12.000 / bln** |
| **6 Bulan** | **Rp 99.000** | **Rp 19.800** | **Rp 79.200** | **Rp 13.200 / bln** |
| **Bulanan** | **Rp 35.000** | **Rp 7.000** | **Rp 28.000** | **Rp 28.000 / bln** |

> **Analisis Bisnis CTO:**  
> Komisi 20% (Rp 36.000) adalah **Biaya Akuisisi Pelanggan (Customer Acquisition Cost / CAC) yang sangat murah dan bebas resiko**. Di industri SaaS POS kompetitor (seperti Majoo/Moka), biaya sales dan iklan digital berkisar antara Rp 150.000 – Rp 300.000 per toko. Dengan sistem mitra, kita **hanya membayar ketika uang kas toko sudah pasti masuk ke rekening**.

---

## 🏷️ 3. Tiga Model Skenario Pendapatan Toko

Untuk melihat dampak potongan mitra secara objektif, kita membandingkan 3 skenario bauran penjualan:
1. **Skenario 1 (100% Direct Organik):** Seluruh toko datang langsung (Play Store/Website), tanpa lewat mitra. Net developer = **Rp 15.000 / toko / bulan**.
2. **Skenario 2 (Bauran Hybrid 50% Mitra / 50% Organik) ⭐:** Kondisi paling realistis di pasar. Sebagian closing dari sales mitra, sebagian install mandiri. Net rata-rata = **Rp 13.500 / toko / bulan**.
3. **Skenario 3 (100% Toko Lewat Mitra):** Skenario paling konservatif di mana seluruh toko direkrut mitra dan dipotong 20%. Net developer = **Rp 12.000 / toko / bulan**.

---

## 📊 4. Tabel Simulasi Laba / Rugi Riil (Memperhitungkan Potongan Mitra 20%)

*Biaya Server Acuan: **Opsi A VPS Self-Hosted (~Rp 170.000 / bulan)***

| Jumlah Toko Aktif | Gross Omset Merchant | Potongan Mitra (20%) | Net Pendapatan Bersih (80%) | Biaya Server (VPS) | Laba/Rugi Bersih Pengembang | Total Uang Kas Bersih di Tangan | Status Finansial |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **0 Toko** | Rp 0 | Rp 0 | Rp 0 | Rp 170.000 | 🔴 **-Rp 170.000** | Rp 0 | Setup Awal |
| **5 Toko** | Rp 75.000 | Rp 15.000 | Rp 60.000 | Rp 170.000 | 🔴 **-Rp 110.000** | Rp 720.000 | Tahap Awal |
| **10 Toko** | Rp 150.000 | Rp 30.000 | Rp 120.000 | Rp 170.000 | 🔴 **-Rp 50.000** | Rp 1.440.000 | Mendekati BEP |
| **15 Toko** ⭐ | **Rp 225.000** | **Rp 45.000** | **Rp 180.000** | **Rp 170.000** | 🟢 **+Rp 10.000 (IMPAS)**| **Rp 2.160.000** | **BEP KASUS 100% MITRA** |
| **20 Toko** | Rp 300.000 | Rp 60.000 | Rp 240.000 | Rp 170.000 | 🟢 **+Rp 70.000** | Rp 2.880.000 | Mulai Surplus |
| **25 Toko** | Rp 375.000 | Rp 75.000 | Rp 300.000 | Rp 170.000 | 🟢 **+Rp 130.000** | Rp 3.600.000 | Batas Kuota Free |
| **50 Toko** | Rp 750.000 | Rp 150.000 | Rp 600.000 | Rp 170.000 | 🟢 **+Rp 430.000** | Rp 7.200.000 | Margin Bersih 71.6% |
| **100 Toko** | Rp 1.500.000 | Rp 300.000 | Rp 1.200.000 | Rp 170.000 | 🟢 **+Rp 1.030.000** | Rp 14.400.000 | Laba Bulanan > Rp 1 Jt |
| **250 Toko** | Rp 3.750.000 | Rp 750.000 | Rp 3.000.000 | Rp 200.000* | 🟢 **+Rp 2.800.000** | Rp 36.000.000 | Mesin Bisnis Matang |
| **500 Toko** | Rp 7.500.000 | Rp 1.500.000 | Rp 6.000.000 | Rp 250.000* | 🟢 **+Rp 5.750.000** | Rp 72.000.000 | Passive Income Kuat |
| **1.000 Toko**| Rp 15.000.000 | Rp 3.000.000 | Rp 12.000.000| Rp 450.000* | 🟢 **+Rp 11.550.000**| Rp 144.000.000 | Skala Nasional |

*\*Catatan: Tabel di atas menghitung kasus terburuk (100% merchant via mitra). Jika ada merchant organik (direct), keuntungan pengembang akan lebih besar lagi.*

---

## 🎯 5. Perbandingan Titik Impas (BEP) Berdasarkan Komposisi Penjualan

```
┌────────────────────────────────────────────────────────────────────────┐
│                TITIK IMPAS TOKO BERBAYAR (BREAK-EVEN POINT)            │
├───────────────────────────────────┬────────────────────────────────────┤
│   OPSI A: VPS SELF-HOSTED (170rb) │   OPSI B: CLOUD PRO ($25 / 500rb)  │
├───────────────────────────────────┼────────────────────────────────────┤
│ 100% Organik     : 12 Toko        │ 100% Organik     : 34 Toko         │
│ Bauran 50% Mitra : 13 Toko ⭐     │ Bauran 50% Mitra : 38 Toko         │
│ 100% Lewat Mitra : 15 Toko        │ 100% Lewat Mitra : 42 Toko         │
└───────────────────────────────────┴────────────────────────────────────┘
```

> **Kesimpulan BEP:**  
> Meskipun ada potongan mitra 20%, **titik impas di VPS hanya bergeser dari 12 toko ke 15 toko (hanya selisih 3 toko!)**. Target ini tetap sangat ringan untuk dicapai seorang founder.

---

## 💵 6. Arus Kas Uang di Muka (*Upfront Cash*) Pasca Potongan Mitra

Uang kas yang diterima pengembang setelah langsung memotong 20% hak mitra:

$$1\text{ Toko Paket 1 Tahun} = \text{Rp } 180.000 - \text{Rp } 36.000 = \mathbf{Rp 144.000\text{ Tunai Bersih}}$$

| Jumlah Toko Lewat Mitra | Total Komisi Dibagi ke Mitra (20%) | Kas Bersih Diterima Pengembang (80%) | Cadangan Operasional Server VPS (Rp 170rb/bln) |
| :---: | :---: | :---: | :---: |
| **5 Toko** | Rp 180.000 | **Rp 720.000** | Cukup bayar server **4,2 Bulan** |
| **10 Toko** | Rp 360.000 | **Rp 1.440.000** | Cukup bayar server **8,5 Bulan** |
| **15 Toko (BEP)** | Rp 540.000 | **Rp 2.160.000** | Cukup bayar server **12,7 Bulan (> 1 Tahun!)** |
| **25 Toko** | Rp 900.000 | **Rp 3.600.000** | Cukup bayar server **21,1 Bulan** |
| **50 Toko** | Rp 1.800.000 | **Rp 7.200.000** | Cukup bayar server **42,3 Bulan (3,5 Tahun!)** |
| **100 Toko** | Rp 3.600.000 | **Rp 14.400.000** | Cukup bayar server **7+ Tahun!** |

---

## 🛣️ 7. SIMULASI LENGKAP: TRANSISI DARI SERVER FREE SAMPAI SERVER BERBAYAR

Bagian ini membedah perjalanan finansial nyata Mangga POS: **Berapa laba saat masih di Server Free, kapan WAJIB migrasi ke Server Berbayar, berapa besar penurunan profitnya saat migrasi, dan kapan profitnya melonjak kembali (The J-Curve Rebound).**

```
                  KURVA TRANSISI PROFIT & MARGIN (THE J-CURVE DIP)

   Margin Laba (%)
    100% ─────────┐ (Fase Server Free ~95%)
                  │
     80%          │                                     ┌─────── (Rebound 85.8% di 100 Toko)
                  │                              ┌──────┘
     60%          │                       ┌──────┘ (71.6% di 50 Toko)
                  └────────┐              │
     40%                   ▼              │
                      DIP MIGRASI KE VPS  │
                      (43.3% di 25 Toko)  │
      0% ──────────────────┴──────────────┴──────────────────────────────────────
                  FASE 1: SERVER FREE   FASE 2: MIGRASI VPS        FASE 3: SKALA
                     (0 - 25 Toko)           (25 Toko)             (50 - 1.000 Toko)
```

---

### A. Tabel Master Transisi: Dari Server Free Menuju Server Berbayar

*Asumsi: Menggunakan bauran realistis (Komisi Mitra 20%, Paket 1 Tahun Rp 180rb = Net Rp 12.000/toko/bln)*

| Tahapan & Jumlah Toko | Status Server & Infrastruktur | Biaya Server / Bln | Gross Omset | Hak Mitra (20%) | Net Pengembang (80%) | Laba Bersih / Bln | Net Margin (%) | Kas Tunai di Rekening | Kondisi Operasional & Tindakan Teknis |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **0 Toko** | **Supabase Free** | Rp 12.500 | Rp 0 | Rp 0 | Rp 0 | 🔴 -Rp 12.500 | 0% | Rp 0 | Biaya hanya domain. Tahap rilis v1.0.12. |
| **5 Toko** | **Supabase Free** | Rp 12.500 | Rp 75.000 | Rp 15.000 | Rp 60.000 | 🟢 **+Rp 47.500** | **79.2%** | **Rp 720.000** | DB ~5 MB. 100% aman di free tier. |
| **10 Toko** | **Supabase Free** | Rp 12.500 | Rp 150.000 | Rp 30.000 | Rp 120.000 | 🟢 **+Rp 107.500** | **89.6%** | **Rp 1.440.000** | DB ~15 MB. Kas di bank mulai menumpuk. |
| **15 Toko** | **Supabase Free** | Rp 12.500 | Rp 225.000 | Rp 45.000 | Rp 180.000 | 🟢 **+Rp 167.500** | **93.1%** | **Rp 2.160.000** | DB ~30 MB. Struk WA masih manual via HP kasir. |
| **20 Toko** | **Supabase Free** | Rp 12.500 | Rp 300.000 | Rp 60.000 | Rp 240.000 | 🟢 **+Rp 227.500** | **94.8%** | **Rp 2.880.000** | DB ~60 MB. Menyiapkan script migrasi VPS. |
| **25 Toko (Peak Free)** ⭐ | **Supabase Free (Batas)**| **Rp 12.500** | **Rp 375.000**| **Rp 75.000** | **Rp 300.000** | 🟢 **+Rp 287.500** | **95.8%** | **Rp 3.600.000** | **PUNCAK FREE TIER.** DB mendekati 250MB. |
| ═════════════════════ | ═════════════════════════ | ═══════════ | ═════════════ | ═════════════ | ════════════════════ | ═════════════════ | ═════════ | ═════════════════ | ══════════════════════════════════════ |
| **25 Toko (MOMEN DIP)** ⚠️ | **MIGRASI KE VPS** 🏆 | **Rp 170.000** | **Rp 375.000**| **Rp 75.000** | **Rp 300.000** | 🟢 **+Rp 130.000** | **43.3%** 🔻 | **Rp 3.600.000** | **MOMEN MIGRASI.** Margin turun tapi disk 40GB! |
| **35 Toko** | **VPS Hetzner / IDCloud** | Rp 170.000 | Rp 525.000 | Rp 105.000 | Rp 420.000 | 🟢 **+Rp 250.000** | **59.5%** | **Rp 5.040.000** | Bot WA otomatis server aktif penuh. |
| **50 Toko** | **VPS Hetzner / IDCloud** | Rp 170.000 | Rp 750.000 | Rp 150.000 | Rp 600.000 | 🟢 **+Rp 430.000** | **71.6%** 🔼 | **Rp 7.200.000** | Margin rebound kembali ke >70%. |
| **100 Toko** | **VPS Hetzner / IDCloud** | Rp 170.000 | Rp 1.500.000 | Rp 300.000 | Rp 1.200.000 | 🟢 **+Rp 1.030.000**| **85.8%** 🔼 | **Rp 14.400.000** | Laba bersih tembus > Rp 1 Juta/bulan. |
| **250 Toko** | **VPS Hetzner / IDCloud** | Rp 200.000 | Rp 3.750.000 | Rp 750.000 | Rp 3.000.000 | 🟢 **+Rp 2.800.000**| **93.3%** | **Rp 36.000.000** | Mesin bisnis berjalan stabil. |
| **500 Toko** | **VPS Cluster (Scale)** | Rp 250.000 | Rp 7.500.000 | Rp 1.500.000 | Rp 6.000.000 | 🟢 **+Rp 5.750.000**| **95.8%** | **Rp 72.000.000** | Cashflow sangat mandiri, siap scale ads. |
| **1.000 Toko** | **VPS Cluster (Scale)** | Rp 450.000 | Rp 15.000.000| Rp 3.000.000 | Rp 12.000.000| 🟢 **+Rp 11.550.000**| **96.2%** | **Rp 144.000.000**| Skala Nasional, passive income stabil. |

---

### B. Bedah Detail: Apa yang Terjadi Saat Pindah Server di Toko ke-25?

Ketika Anda memutuskan pindah dari **Server Free** ke **Server Berbayar** pada toko ke-25:

#### 1. Jika Pindah ke Self-Hosted Supabase di VPS (Rekomendasi Utama 🏆):
* **Biaya Server:** Naik dari **Rp 12.500 $\rightarrow$ Rp 170.000 / bulan** (tambah biaya VPS Rp 75rb + Bot WA server Rp 80rb).
* **Perubahan Angka di Toko ke-25:**
  - Laba Bulanan: Dari **Rp 287.500 $\rightarrow$ Rp 130.000 / bulan** (turun Rp 157.500/bulan).
  - Margin Laba: Turun dari **95.8% $\rightarrow$ 43.3%** (terjadi penurunan -52.5% sementara).
* **Fakta Krusial yang Menyelamatkan Anda:**
  1. **Anda TIDAK PERNAH NOMBOK/RUGI!** Bisnis tetap membukukan laba bersih positif **+Rp 130.000/bulan**.
  2. **Kas Tunai Nyata:** Di rekening bank Anda, sudah terkumpul saldo tunai **Rp 3.600.000** dari pembayaran di muka 25 toko. Saldo ini sanggup membiayai server VPS selama **21 bulan ke depan** meskipun tidak ada toko baru yang masuk!
  3. **Lompatan Kapasitas Teknis:** Database Anda tidak lagi dibatasi 500 MB, melainkan **40 GB (40.000 MB / 80x lebih besar)** dan bebas auto-pause selamanya!

---

#### 2. Jika Pindah ke Supabase Cloud Pro ($25/bln / ~Rp 500.000 Total OpEx):
* **Biaya Server:** Melonjak dari **Rp 12.500 $\rightarrow$ Rp 500.000 / bulan**.
* **Perubahan Angka di Toko ke-25:**
  - Net Omset Pengembang: Rp 300.000 / bulan.
  - Biaya Server: Rp 500.000 / bulan.
  - **Laba/Rugi Bulanan:** 🔴 **DEFISIT / RUGI -Rp 200.000 / bulan (Margin -66.7%)**!
* **Dampaknya:**
  - Terjadi *cash burn* (membakar kas cadangan Rp 200rb setiap bulan).
  - Anda baru bisa kembali ke posisi impas (BEP) jika toko berhasil bertambah dari 25 toko menjadi **42 toko**.
  - **Kesimpulan:** *Inilah alasan kuat mengapa memilih VPS Self-Hosted jauh lebih aman dan ramah cashflow dibanding langsung berlangganan Supabase Cloud Pro.*

---

### C. Pemulihan Profit (The Rebound Curve Menuju 1.000 Toko)

Pasca migrasi ke VPS, margin keuntungan tidak bertahan rendah lama. Begitu toko terus bertambah, margin laba langsung melonjak kembali (*rebound*):

```
Toko 25 (Migrasi)  ──► Margin 43.3%  (Laba Bersih Rp 130.000/bln)
Toko 35            ──► Margin 59.5%  (Laba Bersih Rp 250.000/bln)
Toko 50            ──► Margin 71.6%  (Laba Bersih Rp 430.000/bln)
Toko 100           ──► Margin 85.8%  (Laba Bersih Rp 1.030.000/bln)
Toko 250           ──► Margin 93.3%  (Laba Bersih Rp 2.800.000/bln)
Toko 500           ──► Margin 95.8%  (Laba Bersih Rp 5.750.000/bln)
```

---

## 🏆 8. Kesimpulan & Rekomendasi Eksekutif untuk Kemitraan:
1. **Fase 1 (0 – 25 Toko):** Manfaatkan **Supabase Free** semaksimal mungkin. Kumpulkan kas tunai di muka hingga terkumpul Rp 3 Juta – Rp 4 Juta di rekening.
2. **Fase 2 (Toko ke-25):** Lakukan migrasi ke **Self-Hosted Supabase di VPS (Rp 75rb/bln)**. Margin bulanan memang akan turun sementara ke 43%, namun Anda tetap surplus laba Rp 130rb/bln dan kapasitas storage melompat 80x lipat tanpa resiko database tertidur.
3. **Fase 3 (50 – 100 Toko):** Margin kembali pulih ke **71% – 85%**, menghasilkan arus kas pasif yang stabil untuk mulai menggaji tim atau beriklan.
