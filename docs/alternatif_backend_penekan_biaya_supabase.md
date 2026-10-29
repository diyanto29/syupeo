# 📉 Panduan Alternatif Backend Pengganti Supabase Cloud (Strategi Pangkas Biaya Hingga 85%)
**Mangga POS (SaaS Point of Sales)**  
*Analisis Arsitektur & Perbandingan Biaya oleh CTO*

---

## 🎯 Mengapa Mencari Alternatif Supabase Cloud?

Meskipun **Supabase Cloud** sangat bagus untuk *rapid prototyping*, ada 2 kendala utama bagi startup bootstrap di Indonesia:
1. **Free Tier**: Otomatis *pause* (tidur) jika tidak ada aktivitas selama 7 hari berturut-turut, kuota database dibatasi 500MB, storage 1GB.
2. **Pro Tier**: Biaya tetap **$25 / bulan (~Rp 400.000 – Rp 420.000 / bulan)**. Bagi startup yang baru mulai dan omset belum stabil, pengeluaran ini terasa membebani *cash flow*.

---

## 🏆 Rekomendasi Peringkat Alternatif (CTO Assessment)

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              PILIHAN ALTERNATIF BACKEND                                │
├─────────────────────────┬─────────────────────────┬────────────────────────────────────┤
│   JUARA 1 (BEST CHOICE) │    OPSI 2 (SERVERLESS)  │   OPSI 3 (EXTREME REWRITE)         │
│  Self-Hosted Supabase   │ Neon + Cloudflare R2    │ PocketBase / Go Single Binary      │
│  (VPS Rp 65rb - 100rb)  │ (Free Tier Elastis)     │ (VPS Rp 50rb)                      │
│  Kode Flutter: 0% Ganti │ Kode Flutter: Perlu API │ Kode Flutter: Ganti Total SDK      │
└─────────────────────────┴─────────────────────────┴────────────────────────────────────┘
```

---

## 🥇 OPSI 1 (REKOMENDASI UTAMA): Self-Hosted Supabase di VPS Sendiri
> **Biaya: Rp 65.000 – Rp 120.000 / bulan (Hemat 75% - 85% dibanding Supabase Cloud)**

Supabase adalah proyek **100% Open Source**. Seluruh sistem Supabase (PostgreSQL, PostgREST, GoTrue Auth, Realtime, Storage/MinIO, dan Kong API Gateway) dapat dijalankan di atas 1 VPS murah menggunakan Docker Compose atau panel **Coolify**.

### 🌟 Keunggulan Luar Biasa:
1. **KODE FLUTTER & ADMIN WEB TIDAK BERUBAH SAMA SEKALI (0% Rewrite)!**  
   Cukup ganti `supabaseUrl` ke domain VPS Anda (misal: `https://api.manggapos.online`) dan pasang `anonKey`. Seluruh table, RLS, query, auth Google, dan storage berjalan identik 100%.
2. **Tidak Ada Auto-Pause:** Server aktif 24 jam nonstop 365 hari.
3. **Database & Storage Jauh Lebih Besar:**
   - Supabase Cloud Free: 500 MB DB, 1 GB Storage.
   - VPS Murah (Rp 70rb): **40 GB – 80 GB SSD NVMe**. Bisa menampung ratusan ribu transaksi dan jutaan foto produk.
4. **Lokasi Server di Indonesia / Singapura (Low Latency):**  
   Ping ke kasir hanya **10ms – 25ms** (sangat responsif dibanding Supabase Cloud region luar).

### 🖥️ Pilihan Provider VPS Murah & Andal:
| Provider VPS | Spesifikasi | Lokasi | Biaya Bulanan |
| :--- | :--- | :--- | :--- |
| **Hetzner Cloud (CX22)** | 2 vCPU, 4GB RAM, 40GB NVMe | Singapura / Jerman | **€3.79 (~Rp 65.000)** |
| **IDCloudHost (Cloud VPS)** | 1 vCPU, 2GB RAM, 40GB SSD | Jakarta, Indonesia | **~Rp 80.000 – Rp 100.000** |
| **Contabo (Cloud VPS 1)** | 4 vCPU, 6GB RAM, 100GB NVMe | Singapura | **€5.50 (~Rp 95.000)** |
| **DigitalOcean / Vultr** | 1 vCPU, 1GB RAM, 25GB SSD | Singapura | **$4 – $6 (~Rp 65.000 – Rp 95.000)** |

### 🛠️ Cara Deploy Paling Mudah: Menggunakan Coolify (Self-Hosted PaaS)
1. Sewa VPS Ubuntu 22.04 LTS (contoh di Hetzner atau IDCloudHost).
2. Install Coolify dengan 1 baris perintah:  
   `curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash`
3. Di dashboard Coolify, klik **"+ New Resource"** $\rightarrow$ pilih template **"Supabase"**.
4. Dalam 5 menit, Supabase lengkap dengan Auth, Postgres, dan Storage sudah aktif di domain Anda dengan SSL HTTPS otomatis dari Let's Encrypt.

---

## 🥈 OPSI 2: Arsitektur Hybrid (Neon.tech Serverless + Cloudflare R2)
> **Biaya: Rp 0 – Rp 50.000 / bulan (Free Tier Sangat Luas)**

Jika tidak ingin mengurus VPS (tidak mau repot urus maintenance OS Linux), arsitektur *Serverless Free Tier* terpisah bisa digunakan:

| Kebutuhan | Layanan Pengganti | Model Biaya |
| :--- | :--- | :--- |
| **PostgreSQL Database** | **Neon.tech** (Serverless Postgres) | **Gratis** (0.5 GB storage, autoscaling, no pause) |
| **Media Storage (Foto Produk)** | **Cloudflare R2** | **Gratis** (10 GB storage gratis, **Rp 0 Egress Bandwidth**) |
| **Authentication** | **Firebase Auth** | **Gratis** (Unlimited Google Sign-In) |
| **API Layer** | Next.js API Routes (Vercel) / Cloudflare Workers | **Gratis** |

- **Kelebihan:** 100% *Managed* tanpa perlu sentuh server Linux.
- **Kekurangan:** Perlu memisahkan logic auth dan database di sisi Flutter (ada pekerjaan refactoring kode sekitar 2-3 hari).

---

## 🥉 OPSI 3: PocketBase (Single Executable Go + SQLite)
> **Biaya: Rp 35.000 – Rp 60.000 / bulan**

PocketBase adalah backend *all-in-one* super ringan yang ditulis dalam bahasa Go. Di dalamnya sudah ada: Auth, Database, File Storage, dan Realtime dalam 1 file `.exe` tunggal.
- **Konsumsi Resource:** Hanya butuh RAM 50MB – 100MB! Bisa jalan di VPS paling murah di dunia ($2.5/bln) atau Oracle Cloud Always Free (Rp 0).
- **Kelemahan Fatal untuk Mangga POS:**
  - Menggunakan SQLite di server (kurang cocok untuk multi-tenant banyak cabang yang menulis transaksi bersamaan).
  - **Harus merombak total kode Flutter** dari `supabase_flutter` ke `pocketbase` package. Sangat tidak disarankan jika produk sudah live.

---

## 📊 Matriks Perbandingan Total Biaya & Usaha (Effort)

| Parameter | Supabase Cloud Pro | **Self-Hosted Supabase (VPS)** 🏆 | Neon + Cloudflare R2 | PocketBase |
| :--- | :---: | :---: | :---: | :---: |
| **Biaya Bulanan** | ~Rp 400.000 | **~Rp 65.000 – Rp 100.000** | **Rp 0 – Rp 50.000** | ~Rp 50.000 |
| **Auto-Pause Data?** | Tidak | **Tidak Ada** | Tidak Ada | Tidak Ada |
| **Ukuran Database** | 8 GB | **40 GB – 100 GB** | 500 MB (Free) | Bebas (Disk VPS) |
| **Perubahan Kode Flutter**| **0% (Tanpa ubah)** | **0% (Tanpa ubah sama sekali)** | ~30% Refactor | 100% Rombak Total |
| **Perubahan Admin Web** | **0%** | **0%** | ~20% Refactor | 100% Rombak Total |
| **Waktu Setup** | 0 Menit | **15 - 30 Menit (Via Coolify)** | 2 - 3 Hari | 1 - 2 Minggu |
| **Saran CTO** | Pakai jika sudah ada budget | **PILIHAN TERBAIK UNTUK PANGKAS BIAYA** | Alternatif Serverless | Tidak disarankan |

---

## 🎯 Panduan Keputusan CTO (Action Plan Anda)

Jika tujuan utama Anda adalah **MEMANGKAS BIAYA OPERASIONAL HINGGA MINIMAL TANPA MERUSAK KODE FLUTTER**:

### Rekomendasi Langkah Eksekusi:
1. **Untuk Sekarang (Tahap Launching v1.0.12):**
   - Tetap gunakan Supabase yang ada sekarang.
   - Buat script "Keep-Alive" sederhana (misal cron job ping 1x tiap 3 hari) agar project Supabase Free tidak terkena auto-pause.
2. **Saat Ingin Naik Kapasitas & Bebas Khawatir Tanpa Bayar $25/bulan:**
   - Sewa 1 VPS di **Hetzner Cloud Singapura (CX22)** seharga **€3.79 (~Rp 65.000/bln)** atau **IDCloudHost Jakarta (~Rp 80.000/bln)**.
   - Pasang Supabase Self-Hosted menggunakan **Docker Compose** atau **Coolify**.
   - Migrasikan skema database dan data via `pg_dump` $\rightarrow$ `pg_restore`.
   - Update `app_constants.dart` di Flutter:
     ```dart
     // Cukup ubah URL & Key ke VPS sendiri:
     static const String supabaseUrl = 'https://api.manggapos.online';
     static const String supabaseAnonKey = 'eyJh...vps_self_hosted_key...';
     ```
   - **Hasil:** Anda mendapatkan performa setara Supabase Pro seharga $25, penyimpanan 40GB, tanpa pause, hanya dengan modal **~Rp 65.000 – Rp 80.000 per bulan**!
