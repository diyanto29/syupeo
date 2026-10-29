# DPOS (Mangga POS) Agent & Architecture Guide

Repositori ini adalah sistem **Point of Sale (POS)** multi-platform (Android, Tablet POS, iOS, Desktop Windows/macOS, Web) dengan backend Supabase PostgreSQL, landing page Astro, dan portal Admin Web Next.js.

---

## 1. Direktori Kustomisasi Agen (`.agents/`)

Struktur kustomisasi agen Antigravity telah dikonfigurasi pada folder `.agents/`:

### A. Agent Skills (`.agents/skills/`)
- **[dpos-supabase-backend](file:///Users/diyanto/dpos/.agents/skills/dpos-supabase-backend/SKILL.md)**: Spesifikasi arsitektur backend PostgreSQL Supabase, skema tabel, Row Level Security (RLS), fungsi RPC (`is_admin`, `get_current_partner_id`), dan multi-tenancy.
- **[dpos-pos-engine](file:///Users/diyanto/dpos/.agents/skills/dpos-pos-engine/SKILL.md)**: Logika kalkulasi keranjang kasir, diskon (PWP, BXGY), pajak PB1 & PPN, Kitchen Order Ticket (KOT), manajemen shift, dan offline-first sync.
- **[dpos-thermal-printer](file:///Users/diyanto/dpos/.agents/skills/dpos-thermal-printer/SKILL.md)**: Integrasi printer thermal Bluetooth ESC/POS (58mm & 80mm), pemotong kertas, cash drawer kick, dan layout struk transaksi.
- **[dpos-admin-web](file:///Users/diyanto/dpos/.agents/skills/dpos-admin-web/SKILL.md)**: Panduan pengembangan portal Admin Web (`admin_web`) dengan Next.js 16 App Router, `@supabase/ssr`, Server Actions, otorisasi Super Admin, dan sistem lisensi offline.

### B. Agent Rules (`.agents/rules/`)
- **[feature_structure_and_naming_rule.md](file:///Users/diyanto/dpos/.agents/rules/feature_structure_and_naming_rule.md)**: Standar folder `data/`, `domain/`, `presentation/`, konvensi penamaan berkas/kelas, dan nominal uang Rupiah wajib `int`.
- **[riverpod_and_state_management_rule.md](file:///Users/diyanto/dpos/.agents/rules/riverpod_and_state_management_rule.md)**: Pola state management Riverpod, pemisahan `ref.watch` vs `ref.read`, immutable state, dan lifecycle autoDispose.
- **[responsive_layout_and_tablet_rule.md](file:///Users/diyanto/dpos/.agents/rules/responsive_layout_and_tablet_rule.md)**: Tata letak responsif smartphone vs split-view tablet POS landscape, serta pencegahan `RenderFlex overflow`.
- **[performance_and_smoothness_rule.md](file:///Users/diyanto/dpos/.agents/rules/performance_and_smoothness_rule.md)**: Performa 60fps, kompresi foto produk (<=70KB), cache network image, dan async I/O non-blocking.

---

## 2. Struktur Proyek Utama

```text
dpos/
├── .agents/                 # Agent Skills & Architectural Rules
├── lib/                     # Aplikasi Flutter Multiplatform
│   ├── core/                # Layanan shared (Supabase, theme, routes, utils, sync, bluetooth)
│   └── features/            # Modul fitur bisnis mandiri (pos, inventory, reports, dll.)
├── admin_web/               # Portal Web Manajemen & Super Admin (Next.js 16, Tailwind)
├── landing_page/            # Marketing Landing Page (Astro)
└── supabase/                # Migrasi SQL PostgreSQL & RLS Policies
```
