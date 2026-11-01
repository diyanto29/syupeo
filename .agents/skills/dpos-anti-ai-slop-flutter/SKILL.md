---
name: dpos-anti-ai-slop-flutter
description: Panduan standar arsitektur UI/UX Flutter bebas "AI Slop" untuk Syupeo Kasir Mobile & Tablet POS. Menjamin tampilan tidak tampak seperti template bot generik, menerapkan target sentuh cepat (Fitts's Law), umpan balik haptik, tipografi Inter berangka tabular, dan ketahanan layout layar POS kasir (bebas RenderFlex overflow).
---

# Anti-AI-Slop UI/UX Standard — Syupeo Flutter POS App

Dokumen skill ini dirancang untuk mencegah kode Flutter yang tampak seperti **"AI Slop"** (desain mentah bawaan Material 3 tanpa penyesuaian, target sentuh kekecilan untuk kasir, ketiadaan haptik, dan layout rawan *RenderFlex overflow*).

Aplikasi POS adalah **alat operasional berkecepatan tinggi** yang dipakai kasir berulang kali di bawah tekanan jam sibuk (rush hour).

---

## 1. Definisi & Gejala "AI Slop" di Flutter POS

| Karakteristik "AI Slop" (Dilarang) | Standar Syupeo Production (Wajib) |
|---|---|
| Memakai default Material 3 (warna ungu/pink bawaan, floating action button bulat generik) | Gunakan `AppTheme.primary` (`Color(0xFF0070FC)`), `AppTheme.radiusMd` (8.0), dan `GoogleFonts.inter` |
| Tombol kasir kecil (< 44dp) yang memicu salah tekan saat checkout kilat | **Target Sentuh Minimum 48x48dp**, tombol utama bayar (CTA) tinggi 52–56dp |
| Mengunci layar penuh dengan `CircularProgressIndicator` abu-abu tanpa konteks | Gunakan Shimmer skeleton lokal atau optimistic UI saat menambah item ke keranjang |
| Tidak ada umpan balik taktil saat tombol kasir ditekan | Tambahkan `HapticFeedback.lightImpact()` pada keypad kasir dan tombol pembayaran |
| Layout pecah (*RenderFlex overflowed by ... pixels*) di layar tablet POS atau resolusi berbeda | Desain responsif menggunakan `LayoutBuilder`, `Wrap`, dan `SingleChildScrollView` fleksibel |
| Format angka rupiah tidak rapi dan desimal tidak sejajar di struk/keranjang | Gunakan format Rupiah standar (`Rp 150.000`) dengan font mono / tabular figures |

---

## 2. Standar Desain Layar Kasir (Cashier Ergonomics)

### A. Keypad Kasir & Numpad Ergonomis
Tombol nominal cepat (Quick Cash: Pas, Rp 20rb, Rp 50rb, Rp 100rb) wajib memiliki kontras tinggi dan respon sentuhan instan:
```dart
InkWell(
  onTap: () {
    HapticFeedback.lightImpact();
    onSelectAmount(preset);
  },
  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
  child: Container(
    height: 48,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      border: Border.all(color: AppTheme.border),
    ),
    child: Text(
      presetText,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.text,
      ),
    ),
  ),
)
```

### B. Tombol Aksi Utama (Action Bar)
Layar checkout kasir harus membedakan dengan jelas antara aksi destruktif (Batalkan/Void), aksi sekunder (Simpan Bill / Cetak Dapur), dan aksi primer (Bayar / Checkout):
```dart
Row(
  children: [
    // Tombol Sekunder: Simpan Bill
    Expanded(
      flex: 1,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          side: const BorderSide(color: AppTheme.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
        onPressed: onSaveDraft,
        child: const Text('Simpan'),
      ),
    ),
    const SizedBox(width: 8),
    // Tombol Primer: Bayar
    Expanded(
      flex: 2,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primary,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
        onPressed: onCheckout,
        child: const Text('Bayar Sekarang', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    ),
  ],
)
```

---

## 3. Ketahanan Layout Multi-Perangkat (Tablet 10", Sunmi, & Mobile)

1. **Gunakan Breakpoint Responsif:**
   - Lebar `< 600dp`: Mode Mobile Portrait (Katalog bertingkat, keranjang di bottom-sheet).
   - Lebar `>= 600dp`: Mode Tablet POS (Katalog di sisi kiri 60%, Keranjang checkout tetap di sisi kanan 40%).
2. **Cegah Overflow:**
   - Selalu berikan `minLines: 1, maxLines: 2, overflow: TextOverflow.ellipsis` pada nama produk di katalog.
   - Hindari tinggi statis pada container yang menampung teks dinamis dari database.

---

## 4. Checklist Review Sebelum Menyelesaikan Fitur Flutter
- [ ] Apakah warna primer menggunakan `AppTheme.primary` (`Color(0xFF0070FC)`)?
- [ ] Apakah ukuran target sentuh tombol minimal 48dp?
- [ ] Apakah ada `HapticFeedback.lightImpact()` pada aksi penting (keypad/barcode/bayar)?
- [ ] Apakah layout aman dari `RenderFlex overflow` saat diuji pada layar sempit?
- [ ] Apakah tampilan keranjang dan struk menampilkan angka rupiah terformat rapi?
- [ ] Apakah radius konsisten menggunakan `AppTheme.radiusMd` (8.0)?

