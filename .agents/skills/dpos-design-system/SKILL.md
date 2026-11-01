---
name: dpos-design-system
description: Design System resmi Syupeo untuk Admin Web (Next.js) dan Flutter App. Mengatur color tokens (primary #0070fc, success #10b981, danger #ef4444), typography (Inter), border radius (cards 16px, buttons pill), shadow-only cards, pill tabs, dan status badges.
---

# Syupeo Design System — UI Kit v2

Dokumen ini adalah **referensi tunggal** (single source of truth) untuk implementasi tampilan di:
- **Admin Web** → `admin_web/` (Next.js 16 + Tailwind CSS)
- **Flutter POS App** → `lib/` (Flutter + Material 3)

Visual reference: POS Dashboard dengan sidebar icon-only, kartu putih shadow-only, tombol CTA pill biru, dan tab pill-style.

---

## 1. Color Tokens

| Token | Hex | Dart `Color` | Peran UI |
|-------|-----|--------------|----------|
| `primary` | `#0070fc` | `Color(0xFF0070FC)` | CTA button, aksen brand, link aktif |
| `primary-hover` | `#005ecc` | `Color(0xFF005ECC)` | Hover state tombol primary |
| `secondary` | `#ba8c02` | `Color(0xFFBA8C02)` | Amber accent, warning badge bg |
| `accent` | `#3b82f6` | `Color(0xFF3B82F6)` | Highlight, info elemen |
| `surface` | `#ffffff` | `Color(0xFFFFFFFF)` | Background kartu, modal, panel |
| `surface-subtle` | `#f1f5f9` | `Color(0xFFF1F5F9)` | **Canvas / page background** |
| `surface-low` | `#f8fafc` | `Color(0xFFF8FAFC)` | Subtler tint input bg |
| `surface-highest` | `#e2e8f0` | `Color(0xFFE2E8F0)` | Divider, chip bg |
| `text` | `#0f172a` | `Color(0xFF0F172A)` | Heading / judul utama |
| `text-body` | `#334155` | `Color(0xFF334155)` | Body / paragraf |
| `text-muted` | `#64748b` | `Color(0xFF64748B)` | Subtitle, placeholder, caption |
| `border` | `rgba(0,0,0,0.08)` | `Color(0x14000000)` | Border halus (hanya jika perlu) |
| **`success`** | `#10b981` | `Color(0xFF10B981)` | Status "Ready" / aktif / lunas |
| `success-bg` | `#d1fae5` | `Color(0xFFD1FAE5)` | Badge bg emerald |
| **`warning`** | `#f59e0b` | `Color(0xFFF59E0B)` | Status "Waiting" / pending |
| `warning-bg` | `#fef3c7` | `Color(0xFFFEF3C7)` | Badge bg amber |
| **`danger`** | `#ef4444` | `Color(0xFFEF4444)` | Error, aksi destruktif, hapus |
| `danger-bg` | `#fee2e2` | `Color(0xFFFEE2E2)` | Badge bg merah |
| `info` | `#3b82f6` | `Color(0xFF3B82F6)` | Info banner |

> [!CAUTION]
> **Jangan gunakan** `#3396fa` untuk success atau `#3294f5` untuk danger — itu token lama yang salah. Success = emerald (#10b981), Danger = red (#ef4444).

---

## 2. Typography (Inter)

Gunakan **Google Fonts Inter** untuk semua teks di web dan Flutter.

| Level | Size | Weight | Color | Line-height |
|-------|------|--------|-------|-------------|
| Display | 36px | 800 | `text` `#0f172a` | 1.15 |
| H1 / headlineMedium | 28px | 700 | `text` | 1.25 |
| H2 / headlineSmall | 22px | 600 | `text` | 1.35 |
| Title / titleLarge | 22px | 600 | `text` | 1.35 |
| titleMedium | 16px | 600 | `text` | — |
| titleSmall | 14px | 600 | `text` | — |
| Body Large | 16px | 400 | `text-body` `#334155` | 1.65 |
| Body Medium | 14px | 400 | `text-body` | 1.55 |
| Caption / bodySmall | 12px | 500 | `text-muted` `#64748b` | 1.40 |
| Label | 12px | 600 | `text` | — |

---

## 3. Radii & Shadow

### Radius Scale

| Token | Value | Penggunaan |
|-------|-------|------------|
| `sm` | 6px | Chip kecil, micro-badge |
| `md` | 12px | Input field, modal kecil |
| `lg` | 16px | **Default kartu & panel** |
| `xl` | 24px | Drawer, bottom sheet |
| `full` | 9999px | **Pill button CTA, pill tab, avatar** |

### Shadow — Shadow-Only Cards (NO colored border)

Kartu Syupeo **tidak** memiliki border berwarna. Gunakan shadow saja:

```
card shadow:    box-shadow: 0 2px 8px 0 rgba(0,0,0,0.08)
panel shadow:   box-shadow: 0 1px 4px 0 rgba(0,0,0,0.06)
elevated:       box-shadow: 0 4px 16px 0 rgba(0,0,0,0.08)
```

Flutter equivalen:
```dart
BoxDecoration(
  color: AppTheme.surface,
  borderRadius: BorderRadius.circular(AppTheme.radiusLg), // 16px
  boxShadow: [
    BoxShadow(
      color: Color(0x14000000), // rgba(0,0,0,0.08)
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ],
)
```

---

## 4. Component Patterns

### 4.1 Card (kartu produk, order card, dsb.)

```tsx
// Web — Tailwind
<div className="bg-white rounded-lg shadow-md p-4">
  {/* rounded-lg = 16px, shadow-md = 0 2px 8px rgba(0,0,0,0.08) */}
</div>
// atau gunakan utility class:
<div className="syupeo-card p-4">...</div>
```

```dart
// Flutter
Container(
  decoration: BoxDecoration(
    color: AppTheme.surface,
    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
    boxShadow: const [BoxShadow(color: AppTheme.shadowDiffused, blurRadius: 8, offset: Offset(0, 2))],
  ),
)
```

### 4.2 CTA Button — Pill, Full Blue

```tsx
// Web
<button className="btn-pill w-full">Confirm Payment</button>
// atau Tailwind:
<button className="w-full bg-primary text-white rounded-full py-3 font-semibold hover:bg-primary-hover transition-colors min-h-[52px]">
```

```dart
// Flutter — FilledButton sudah dikonfigurasi sebagai pill di AppTheme
FilledButton(onPressed: () {}, child: Text('Konfirmasi Pembayaran'))
// Otomatis: rounded-full (radiusFull), height 52px
```

### 4.3 Pill Segmented Tabs

Aktif = white bg + shadow. Tidak aktif = gray text, transparent bg.

```tsx
// Web
<div className="tab-pill-group">
  <button className="tab-pill active">All Orders <span className="badge">24</span></button>
  <button className="tab-pill">Dine In</button>
  <button className="tab-pill">Take Away</button>
</div>
```

```dart
// Flutter — gunakan custom widget atau ToggleButtons dengan decoration
// Active tab: Container(color: white, borderRadius: BorderRadius.circular(999), boxShadow: ...)
// Inactive: Text only, gray
```

### 4.4 Status Badges

```tsx
// Web
<span className="badge-waiting">Waiting</span>   {/* amber */}
<span className="badge-ready">Ready</span>       {/* emerald */}
<span className="badge-danger">Error</span>      {/* red */}
```

```dart
// Flutter
Container(
  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: AppTheme.warningBg,  // #fef3c7
    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
  ),
  child: Text('Waiting', style: TextStyle(color: Color(0xFF92400E), fontSize: 12, fontWeight: FontWeight.w600)),
)
```

### 4.5 Quantity Stepper

```tsx
// Web
<div className="qty-stepper">
  <button>−</button>
  <span>1</span>
  <button>+</button>
</div>
```

```dart
// Flutter
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    OutlinedButton(onPressed: onDecrement, child: Icon(Icons.remove, size: 16)),
    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('$qty')),
    OutlinedButton(onPressed: onIncrement, child: Icon(Icons.add, size: 16)),
  ],
)
```

### 4.6 Sidebar — Icon-Only (64px wide)

- Width: `64px` (web) / `64.0` (Flutter)
- Icon size: 24px
- Active icon: blue pill background `#0070fc` dengan white icon
- Inactive: dark icon `#0f172a` atau muted
- No labels visible (icon-only)

```tsx
// Web sidebar active nav item
<button className="flex items-center justify-center w-10 h-10 rounded-full bg-primary text-white">
  <Icon />
</button>
// Inactive:
<button className="flex items-center justify-center w-10 h-10 rounded-full text-[#64748b] hover:bg-[#f1f5f9]">
  <Icon />
</button>
```

---

## 5. Implementasi Admin Web (`admin_web/`)

### Tailwind Config (`tailwind.config.ts`)
Token sudah dikonfigurasi. Gunakan:
- `bg-primary` → `#0070fc`
- `text-success` → `#10b981`
- `text-danger` → `#ef4444`
- `bg-surface-subtle` → `#f1f5f9` (page canvas)
- `rounded-lg` → 16px (cards)
- `rounded-full` → pill (buttons, tabs, badges)
- `shadow-md` → card shadow

### CSS Variables (`src/app/globals.css`)
```css
--primary: #0070fc;
--success: #10b981;
--danger: #ef4444;
--surface-subtle: #f1f5f9;  /* page bg */
--shadow-card: 0 2px 8px 0 rgba(0,0,0,0.08);
```

### Utility Classes
- `.syupeo-card` — white card, 16px radius, shadow-only
- `.syupeo-panel` — panel sidebar / modal
- `.btn-pill` — CTA button full-rounded blue
- `.btn-pill-outline` — outline pill button
- `.tab-pill-group` / `.tab-pill` / `.tab-pill.active` — segmented tabs
- `.badge-waiting` / `.badge-ready` / `.badge-danger` — status pills
- `.qty-stepper` — quantity stepper control

---

## 6. Implementasi Flutter App (`lib/`)

### Theme Provider (`lib/core/theme/app_theme.dart`)

```dart
AppTheme.primary       = Color(0xFF0070FC)  // blue CTA
AppTheme.success       = Color(0xFF10B981)  // emerald — ready/lunas
AppTheme.warning       = Color(0xFFF59E0B)  // amber — waiting/pending
AppTheme.danger        = Color(0xFFEF4444)  // red — error/hapus
AppTheme.surface       = Color(0xFFFFFFFF)  // card bg
AppTheme.surfaceSubtle = Color(0xFFF1F5F9)  // scaffold/canvas bg
AppTheme.text          = Color(0xFF0F172A)  // heading
AppTheme.textBody      = Color(0xFF334155)  // body
AppTheme.textMuted     = Color(0xFF64748B)  // caption
AppTheme.radiusLg      = 16.0  // default card radius
AppTheme.radiusFull    = 9999.0 // pill button / tabs
```

- `scaffoldBackgroundColor`: `surfaceSubtle` (#f1f5f9) ✅
- `CardTheme`: no border, shadow-only, `radiusLg` (16px) ✅
- `FilledButton`: pill shape (`radiusFull`), height 52px ✅
- Font: **Inter** via `google_fonts` ✅

---

## 7. Anti-AI Slop Rules

> [!IMPORTANT]
> Ikuti skill `dpos-anti-ai-slop-web` dan `dpos-anti-ai-slop-flutter` untuk standar anti-generik.

- **Jangan** pakai border berwarna pada kartu — gunakan shadow saja
- **Jangan** pakai underline-style tab — gunakan pill tabs dengan active white bg
- **Jangan** pakai tombol dengan border-radius kecil untuk CTA utama — selalu pill (`rounded-full`)
- **Jangan** gunakan warna orange/amber sebagai primary action — Syupeo Blue (`#0070fc`) saja
- Semua list query: `.order('created_at', { ascending: false })`
