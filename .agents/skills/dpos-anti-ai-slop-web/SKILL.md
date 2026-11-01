---
name: dpos-anti-ai-slop-web
description: Panduan standar frontend bebas "AI Slop" untuk Syupeo Admin Web & Merchant Portal (Next.js 16, React 19/18, Tailwind CSS). Mencegah template generik, memaksakan token warna resmi (#0070fc), tipografi Inter tabular, kelengkapan micro-states (skeleton, empty state), dan densitas data bisnis tingkat produksi.
---

# Anti-AI-Slop Frontend Standard — Syupeo Admin Web

Dokumen skill ini dibuat terinspirasi dari standar arsitektur UI tingkat lanjut (`claude-skills` & design systems) khusus untuk mencegah kode dan tampilan web yang tampak seperti **"AI Slop"** (desain generik bot: gradasi ungu klise, kartu mengambang tak berguna, tanpa hierarki data, dan tidak responsif).

---

## 1. Definisi & Gejala "AI Slop" di Admin Web

| Karakteristik "AI Slop" (Dilarang) | Standar Syupeo Production (Wajib) |
|---|---|
| Menggunakan warna ungu/indigo generik (`#8b5cf6`, `bg-purple-600`) | Gunakan warna token resmi Syupeo: Primary `#0070fc`, Secondary `#ba8c02`, Text `#1a1a1a` |
| Mengambangkan kartu berlebihan dengan radius raksasa (`rounded-3xl`) | Gunakan radius konsisten 8px (`rounded-md`) sesuai [dpos-design-system](file:///Users/diyanto/syupeo/.agents/skills/dpos-design-system/SKILL.md) |
| Hanya membuat layout statis tanpa loading / empty state | **Wajib 4 Status Lengkap:** Data Rendered, Skeleton Shimmer, Actionable Empty State, dan Error Banner |
| Format angka rupiah tidak rapi dan bergeser di tabel | Gunakan `font-mono tracking-tight tabular-nums text-right` untuk nilai finansial/omzet |
| Card kosong tanpa fungsi operasional (sekadar hiasan) | Setiap card menyajikan data riil (metrik, persentase delta, filter tanggal, atau quick action) |
| Input form tanpa validasi visual, label tanpa `htmlFor` | Formulir wajib terstruktur dengan label aksesibel, hint teks, fokus ring `#0070fc`, dan error inline |

---

## 2. Aturan Tipografi & Densitas Data

1. **Format Finansial / Rupiah:**
   ```tsx
   // BENAR: Menggunakan tabular-nums dan perataan kanan di tabel
   <td className="px-4 py-3 text-right font-mono text-sm font-semibold text-slate-900 tabular-nums">
     {formatRupiah(transaction.total_amount)}
   </td>
   ```
2. **Hierarki Kontras & Teks:**
   - Judul Utama / H1: `text-xl font-bold text-slate-900 tracking-tight`
   - Label Kolom Tabel: `text-xs font-semibold text-slate-500 uppercase tracking-wider`
   - Data Sekunder / Timestamp: `text-xs text-slate-400`
   - Dilarang memakai warna abu-abu terlalu terang yang gagal kontras WCAG AAA (< 4.5:1).

---

## 3. Komponen Wajib Bebas Slop

### A. Actionable Empty State
Jangan pernah menampilkan layar kosong putih atau tulisan mentah *"Tidak ada data"*.
```tsx
export function TableEmptyState({ onAction, title, description }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center p-12 text-center bg-white rounded-md border border-slate-200/80">
      <div className="w-12 h-12 rounded-full bg-blue-50 flex items-center justify-center text-primary mb-3">
        <PackageX className="w-6 h-6 text-primary" />
      </div>
      <h3 className="text-sm font-bold text-slate-900 mb-1">{title}</h3>
      <p className="text-xs text-slate-500 max-w-sm mb-4">{description}</p>
      {onAction && (
        <button
          onClick={onAction}
          className="inline-flex items-center gap-2 px-3.5 py-2 rounded-md bg-primary hover:bg-primary-hover text-white text-xs font-semibold transition-all shadow-xs"
        >
          <Plus className="w-4 h-4" />
          <span>Tambah Data Baru</span>
        </button>
      )}
    </div>
  );
}
```

### B. Skeleton Shimmer (Bukan Spinner Putar Biasa)
```tsx
export function MetricCardSkeleton() {
  return (
    <div className="p-5 bg-white rounded-md border border-slate-200 animate-pulse">
      <div className="h-3 w-24 bg-slate-100 rounded mb-3" />
      <div className="h-7 w-36 bg-slate-200 rounded mb-2" />
      <div className="h-3 w-20 bg-slate-100 rounded" />
    </div>
  );
}
```

### C. Tactile Button Interaction
- Tombol aksi utama wajib memiliki visual feedback saat ditekan:
  `active:scale-[0.98] transition-transform duration-100`
- Border focus yang jelas untuk navigasi keyboard:
  `focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary`

---

## 4. Checklist Review Sebelum Menyelesaikan Fitur Web
- [ ] Apakah warna primer menggunakan `#0070fc` (bukan ungu/indigo default AI)?
- [ ] Apakah border radius konsisten 8px (`rounded-md`) pada card, modal, dan button?
- [ ] Apakah ada penanganan saat data kosong (`empty state`) dengan tombol ajakan bertindak?
- [ ] Apakah ada state loading berbasis skeleton shimmer?
- [ ] Apakah angka uang menggunakan `tabular-nums` dan rata kanan pada tabel?
- [ ] Apakah form input dilengkapi state focus jelas dan pesan error jika input invalid?

