# Release Notes - Mangga POS v1.0.14 (Build 25) & Web Backoffice

**File Bundle:** [app-release.aab](file:///Users/diyanto/dpos/build/app/outputs/bundle/release/app-release.aab) (Ukuran: 68 MB)  
**Portal Web Merchant:** [https://app.mudahkan.online](https://app.mudahkan.online)  
**Toko Online Pelanggan:** [https://pos.mudahkan.online](https://pos.mudahkan.online)  

---

### 🇮🇩 Bahasa Indonesia (Play Store / Ringkas)
```text
Pembaruan Mangga POS v1.0.14:
• AI Assistant Interaktif: AI kini bisa berbicara langsung membalas dalam Bahasa Indonesia (Text-to-Speech) dengan kontrol audio speaker.
• Tampilan Chat Rapi: Format teks pesan AI tampil elegan & bersih tanpa simbol mentah Markdown.
• Deep Business Analytics: Prediksi stok habis (burn rate), rekomendasi promo bundling hemat, dan analisis jam sepi (Happy Hour).
• AI Business Copilot di Web Portal: Analisis bisnis toko kini dapat diakses langsung dari browser laptop di app.mudahkan.online/merchant/ai.
• Upgrade Model AI: Didukung model Gemini 3.8 Flash generasi terbaru untuk respons cepat dan akurat.
• Perbaikan Checkout Toko Online: Alur WhatsApp lebih responsif tanpa terhalang popup blocker.
• Peningkatan kestabilan & performa kasir POS.
```

---

### 🇬🇧 English (Google Play Console)
```text
What's new in v1.0.14:
• Interactive AI Assistant: AI now speaks back in Indonesian (Text-to-Speech) with speaker audio controls.
• Clean Rich Markdown: Chat messages render with clean typography, eliminating raw markdown symbols.
• Deep Business Analytics: Stock depletion predictions (burn rate), smart bundling recommendations, and peak/slow hours analysis.
• AI Business Copilot in Web Portal: Access intelligent store analytics from your laptop at app.mudahkan.online/merchant/ai.
• Gemini 3.8 Flash Engine: Upgraded to Google's latest AI model for blazing-fast responses and reasoning.
• Online Store Checkout Fix: Seamless WhatsApp checkout without popup blocker interference.
• Performance and stability improvements across the POS app.
```

---

### 📋 Rincian Pembaruan Fitur Lengkap

#### 1. 🎙️ AI Assistant Interaktif (Dua Arah & Suara Alami)
* **Text-to-Speech (Bicara Balik):** Saat AI menjawab pertanyaan kasir atau pemilik toko, AI dapat berbicara membalas langsung menggunakan sintesis suara Bahasa Indonesia yang natural.
* **Kontrol Suara (Mute/Unmute):** Tombol speaker di bagian atas layar memungkinkan pengguna menyalakan atau membisukan suara balasan dengan satu ketukan.
* **Tombol Audio & Salin Per Pesan:** Setiap pesan balasan AI dilengkapi tombol pemutar suara individu serta tombol salin ke *clipboard*.

#### 2. ✨ Tampilan Pesan Elegan (Rich Markdown Rendering)
* **Bebas Simbol Mentah:** Menghilangkan tampilan simbol sintaks mentah seperti `###`, `**`, dan `*`.
* **Tipografi Bersih:** Judul poin, bullet list, dan teks tebal terformat secara visual dengan rapi dan terstruktur baik di aplikasi Android maupun Web Portal.

#### 3. 🧠 Deep Business Intelligence & Prediksi Stok
* **Prediksi Stok Habis (Burn Rate Estimation):** Mengalkulasikan kecepatan penjualan rata-rata harian dengan sisa stok untuk memperkirakan hari kehabisan produk dan waktu ideal berbelanja ke supplier.
* **Menu Engineering & Bundling Pintar:** Memberikan rekomendasi paket promo bundling yang menggabungkan produk terlaris dengan produk bermargin tinggi guna meningkatkan *Average Order Value (AOV)*.
* **Strategi Jam Sepi (Happy Hour):** Menganalisis kurva jam sibuk toko dan merekomendasikan jam promo diskon pada jam-jam sepi pengunjung.

#### 4. 💻 AI Business Copilot di Web Portal (`https://app.mudahkan.online/merchant/ai`)
* **Akses Desktop/Laptop:** Pemilik toko dapat berkonsultasi mengenai analitik toko langsung melalui browser komputer.
* **Floating AI Button:** Tombol melayang di pojok kanan bawah yang memudahkan akses AI dari menu produk, transaksi, maupun laporan.
* **Dukungan Web Speech API:** Fitur rekam suara via mikrofon dan suara balasan AI langsung berjalan di peramban (Chrome, Edge, Safari).
* **Ringkasan Real-Time Bar:** Kartu statistik instan menampilkan Omzet Hari Ini, Transaksi, Laba Bersih, dan Jumlah Stok Kritis.

#### 5. ⚡ Mesin AI Generasi Baru (Gemini 3.8 Flash)
* Mengadopsi model **Gemini 3.8 Flash** sebagai mesin utama di mobile dan web backend untuk kecepatan inferensi sub-detik dan pemahaman konteks bisnis yang lebih mendalam.
