# Design System Document: The Precision Concierge

## 1. Overview & Creative North Star
**Creative North Star: The Precision Concierge**
In the high-pressure environment of hospitality, a POS should not feel like a spreadsheet; it should feel like a high-end, editorial experience. This design system moves away from the "utility-first" clutter of legacy systems toward a "Precision Concierge" aesthetic. We combine the authoritative weight of Deep Navy with the kinetic energy of Vibrant Orange. 

The system breaks the "template" look by utilizing extreme typographic scale, intentional asymmetry in layout, and a "tonal layering" approach to depth. We prioritize breathing room and optical clarity, ensuring that even in a dimly lit dining room or a frantic kitchen pass, the waiter's next move is intuitive and effortless.

---

## 2. Colors
Our palette is rooted in the reliability of the sea and the urgency of fire. We use Material 3 token logic but apply them with an editorial eye.

*   **Primary Foundation:** `primary_container` (#371A00) and `secondary` (#465F88) form the bedrock of the UI. The Navy dominance creates a calm, focused environment.
*   **The Action Spark:** `primary` (#160700) and the vibrant orange highlights (#FF8C00) are reserved strictly for movement—starting orders, sending to kitchen, and processing payments.

### The "No-Line" Rule
**Explicit Instruction:** You are prohibited from using 1px solid borders to section off the UI. 
Boundaries must be defined solely through background color shifts. For example, a sidebar using `surface-container-low` sits directly against a `surface` main content area. The eye perceives the break through the shift in value, not a rigid line.

### Surface Hierarchy & Nesting
Treat the UI as a physical stack of fine materials.
*   **Level 0 (Base):** `surface` (#F9F9FE) – The floor of the application.
*   **Level 1 (Sections):** `surface-container-low` (#F3F3F8) – Large organizational blocks.
*   **Level 2 (Interaction):** `surface-container-highest` (#E2E2E7) – Hover states or active card selections.
*   **Level 3 (Focus):** `surface-container-lowest` (#FFFFFF) – The "top" sheet, reserved for the most critical data entry cards to provide maximum contrast.

### The "Glass & Gradient" Rule
To elevate the system, use Glassmorphism for floating overlays (like order modifiers). Apply `surface` colors at 80% opacity with a `24px` backdrop-blur. 
**Signature Texture:** Main CTAs (like "Checkout") should not be flat orange. Use a subtle linear gradient from `primary` (#160700) to a slightly lighter tonal variant to give the button "soul" and a tactile, rounded appearance.

---

## 3. Typography
We use a dual-font strategy to balance character with utility.

*   **Display & Headlines (Manrope):** This is our "Editorial" voice. Manrope’s geometric but warm curves are used for Table Numbers, Total Amounts, and Section Headers. The high contrast between `display-lg` (3.5rem) and `headline-sm` (1.5rem) creates a clear visual anchor.
*   **Body & Labels (Inter):** The "Workhorse." Inter is used for menu item descriptions, seat numbers, and timestamps. It is optimized for legibility at small scales (e.g., `label-sm` at 0.6875rem) in high-speed environments.

**Identity Tip:** Use `letter-spacing: -0.02em` on all Manrope headlines to give them a premium, tightly-kerned "magazine" feel.

---

## 4. Elevation & Depth
Traditional shadows are often "dirty." We use Tonal Layering and Ambient Light.

*   **The Layering Principle:** Instead of a shadow, place a `surface-container-lowest` card on a `surface-container-low` background. This creates a "soft lift" that feels architectural.
*   **Ambient Shadows:** For the Floating Action Button (FAB) or high-priority modals, use a diffused shadow: 
    *   `box-shadow: 0px 12px 32px rgba(0, 33, 71, 0.08);` 
    *   Note the color: We use a tinted Navy (#002147) at low opacity rather than pure black.
*   **The "Ghost Border" Fallback:** If accessibility requires a container definition (e.g., in high-glare environments), use the `outline-variant` token at **15% opacity**. It should be felt, not seen.

---

## 5. Components

### Cards & Tables (The Table Grid)
Forbid the use of divider lines. 
*   **Available Table:** Card background `surface-container-lowest`, Status Indicator `tertiary_fixed` (#A3F69C).
*   **Active Table:** Card background `secondary_fixed` (#D6E3FF), Status Indicator `secondary` (#465F88).
*   **Validation Required:** Card background `primary_fixed` (#FFDCC3), Status Indicator `on_primary_container` (#CE7000).
*   **Spacing:** Use a strict 24px internal padding for cards to ensure touch targets are "waiter-thumb" friendly.

### Buttons
*   **Primary (The Orange Strike):** Uses the Orange #FF8C00. Roundedness set to `xl` (0.75rem). Use `on_primary` (#FFFFFF) for text.
*   **Secondary:** Ghost style. No background, `outline` token at 20% opacity, text in `secondary`.
*   **FAB:** The "Action Hub." Must be `primary` (Orange) with a `full` (9999px) roundedness. Positioned with a 32px offset from the bottom-right to avoid accidental palms-touches.

### Lists & Input Fields
*   **The Order List:** Use `surface-container-low` for alternating items instead of lines. 
*   **Input Fields:** Use "Soft Fields." No bottom line. A subtle `surface-variant` background with a `md` (0.375rem) corner radius. When focused, the background shifts to `surface-container-lowest` with a 2px `primary` (Orange) ghost border.

---

## 6. Do's and Don'ts

### Do:
*   **Embrace Negative Space:** If a screen feels "empty," it’s working. High-end dining is about focus, not clutter.
*   **Use Tonal Shifts:** Use `surface-dim` to push secondary information (like "Tax" or "Server ID") into the background.
*   **Asymmetric Focus:** Place the "Total" in a massive `display-md` type size, while the "Table Number" remains a sophisticated `title-sm`.

### Don't:
*   **No 1px Dividers:** Never use a solid line to separate menu categories. Use a header with 32px top-margin instead.
*   **No Pure Black Shadows:** Shadows must always be tinted with the Deep Navy `primary` color to maintain the "premium" color harmony.
*   **No Default "Inter" Headlines:** Never use Inter for anything above `title-lg`. It lacks the editorial authority of Manrope.
*   **No High-Contrast Borders:** Avoid the `outline` token at 100% opacity; it breaks the "Precision Concierge" softness.