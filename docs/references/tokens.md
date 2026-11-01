# Design System Tokens

## Color Tokens

| Token | CSS Variable | Hex / Value | Role / Usage |
|-------|--------------|-------------|--------------|
| `primary` | `--primary` | `#0070fc` | Primary actions, CTA buttons, active links, brand accents |
| `primary-hover` | `--primary-hover` | `#005ecc` | Hover state for primary buttons and interactive elements |
| `secondary` | `--secondary` | `#ba8c02` | Secondary actions, badges, highlight indicators |
| `accent` | `--accent` | `#548ce0` | Supporting visual interest, decorative elements |
| `surface` | `--surface` | `#ffffff` | Background for pages, cards, modals, popovers |
| `surface-subtle` | `--surface-subtle` | `#f8fafc` | Subtle page background, secondary containers |
| `text` | `--text` | `#1a1a1a` | Primary text, titles, headings, and high-emphasis labels |
| `text-muted` | `--text-muted` | `#64748b` | Supporting text, captions, placeholder text |
| `border` | `--border` | `rgba(26, 26, 26, 0.12)` | Subtle borders, dividers, outline separators |
| `success` | `--success` | `#3396fa` | Positive feedback, success badges, completed states |
| `warning` | `--warning` | `#ba8c02` | Cautionary indicators, alerts, pending badges |
| `danger` | `--danger` | `#3294f5` | Error messages, destructive actions, critical notices |
| `info` | `--info` | `#548ce0` | Information banners, helper notes, neutral badges |

---

## Typography Scale (Inter)

| Name | Size | Weight | Line Height | Role |
|------|------|--------|-------------|------|
| **Display** | 36px (2.25rem) | 800 (Extra Bold) | 1.15 | Hero metrics, banner titles |
| **H1** | 28px (1.75rem) | 700 (Bold) | 1.25 | Page titles, major section headings |
| **H2** | 22px (1.375rem) | 600 (Semi Bold) | 1.35 | Section headers, card titles |
| **Body** | 16px (1.0rem) | 400 (Regular) | 1.65 | Standard body copy, descriptions |
| **Small** | 14px (0.875rem) | 400 (Regular) / 500 | 1.55 | Table contents, compact inputs, secondary copy |
| **Caption** | 12px (0.75rem) | 500 (Medium) | 1.40 | Timestamps, tags, micro-copy, badges |

---

## Layout & Radii

| Token | Value | Applied To |
|-------|-------|------------|
| `radius-sm` | `4px` | Small tags, sub-pills, badges |
| `radius-md` | `8px` | Buttons, cards, modals, text inputs (Default) |
| `radius-lg` | `16px` | Floating sheets, large cards, dialogs |
| `radius-xl` | `24px` | Drawer panels, hero containers |
| `radius-full` | `9999px` | Avatars, status pills, circular action icons |

---

## Shadows

- **sm**: `0 1px 2px 0 rgba(26, 26, 26, 0.04)`
- **md**: `0 4px 6px -1px rgba(26, 26, 26, 0.05), 0 2px 4px -2px rgba(26, 26, 26, 0.05)`
- **lg**: `0 10px 15px -3px rgba(26, 26, 26, 0.06), 0 4px 6px -4px rgba(26, 26, 26, 0.04)`

