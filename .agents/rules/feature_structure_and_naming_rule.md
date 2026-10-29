# Aturan Struktur Folder Fitur, Konvensi Penamaan & Standar Data DPOS

Dokumen aturan ini menetapkan standarisasi resmi struktur folder, konvensi penamaan simbol/berkas, dan penanganan tipe data di seluruh modul Flutter aplikasi **DPOS (Mangga POS)**.

---

## 1. Struktur Folder Standar Fitur (`lib/features/<nama_fitur>/`)

Setiap modul fitur di dalam `lib/features/` **WAJIB** menerapkan struktur layering seragam berikut:

```text
lib/features/<nama_fitur>/
├── data/
│   ├── <nama>_repository.dart       # Komunikasi dengan remote Supabase API & lokal SQLite
│   └── <nama>_service.dart          # Layanan teknis (misal: export Excel, enkripsi, bluetooth)
├── domain/
│   ├── <nama>_models.dart           # Entity data model (immutable, copyWith, fromJson/toJson)
│   └── <nama>_enums.dart            # Enum spesifik fitur (status, tipe pesanan, metode bayar)
└── presentation/
    ├── providers/                   # State notifier & Riverpod providers (*_provider.dart)
    ├── views/                       # Layar tampilan utama (*_screen.dart, *_view.dart)
    └── widgets/                     # Komponen widget modular & reusable (*_card.dart, *_sheet.dart)
```

> **Larangan:** Dilarang meletakkan screen atau state provider di luar modul fiturnya atau mencampur aduk kode logika repository ke dalam tampilan UI.

---

## 2. Konvensi Penamaan Berkas & Simbol (Naming Conventions)

| Komponen | Pola Penamaan Berkas | Pola Penamaan Kelas | Lokasi Folder | Ketentuan Wajib |
|---|---|---|---|---|
| **Model** | `<nama>_models.dart` | `<Nama>Model` | `domain/` | Seluruh field `final`, wajib `copyWith()` & `fromJson` |
| **Repository** | `<nama>_repository.dart` | `<Nama>Repository` | `data/` | Menangani try-catch & konversi error Supabase |
| **Provider** | `<nama>_provider.dart` | `<nama>Provider` / `<Nama>Notifier` | `presentation/providers/` | Menggunakan Riverpod StateNotifier / Notifier |
| **Screen / View** | `<nama>_screen.dart` | `<Nama>Screen` | `presentation/views/` | `ConsumerStatefulWidget` / `ConsumerWidget` |
| **Sheet Modal** | `<nama>_sheet.dart` | `<Nama>Sheet` | `presentation/views/` atau `widgets/` | Modal bottom sheet responsif |
| **Widget Komponen** | `<nama>_card.dart` / `<nama>_item.dart` | `<Nama>Card` | `presentation/widgets/` | 1 berkas = 1 komponen independen |

---

## 3. Standar Penanganan Mata Uang (Rupiah)

1. **WAJIB Bertipe `int` (Bilangan Bulat):**
   - Seluruh nominal uang di DPOS (`price`, `subtotal`, `tax_amount`, `discount_amount`, `total_amount`, `cash_received`, `change`) **HARUS bertipe `int`**.
   - Dilarang menggunakan `double` untuk nominal Rupiah guna mencegah kesalahan pembulatan desimal (*floating-point rounding errors*) pada transaksi kasir.
2. **Format Tampilan Rupiah:**
   - Gunakan format mata uang baku Indonesia: `NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)` atau helper `RupiahInputHelper`.

---

## 4. Standar Tanggal & ID

1. **Format Tanggal:**
   - Pertukaran data tanggal dan penyimpanan database wajib menggunakan format ISO-8601 (`DateTime.now().toIso8601String()`).
2. **Format ID:**
   - Kunci utama database menggunakan UUID (`uuid.v4()`).
   - Kode transaksi menggunakan format prefix tanggal: misal `POS-YYYYMMDD-XXXX` atau `INV-YYYYMMDD-XXXX`.
