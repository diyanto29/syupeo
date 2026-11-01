import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        // Syupeo Design System Tokens v2 — matches image style guide
        primary: {
          DEFAULT: "#0070fc",
          hover: "#005ecc",
          50: "#eff6ff",
          100: "#dbeafe",
          200: "#bfdbfe",
          300: "#93c5fd",
          400: "#60a5fa",
          500: "#0070fc",
          600: "#005ecc",
          700: "#004db3",
          800: "#003c8c",
          900: "#002a66",
        },
        secondary: {
          DEFAULT: "#ba8c02",
          50: "#fefce8",
          100: "#fef9c3",
          500: "#ba8c02",
          600: "#a17800",
        },
        accent: {
          DEFAULT: "#3b82f6",
          50: "#eff6ff",
          100: "#dbeafe",
          500: "#3b82f6",
          600: "#2563eb",
        },
        surface: {
          DEFAULT: "#ffffff",
          subtle: "#f1f5f9", // canvas / page background
          50: "#f8fafc",
          100: "#f1f5f9",
          200: "#e2e8f0",
          300: "#cbd5e1",
          800: "#0f172a",
          900: "#090d16",
          950: "#05080e",
        },
        text: {
          DEFAULT: "#0f172a", // near-black heading
          body: "#334155",   // body text
          muted: "#64748b",  // subtitle / caption
        },
        border: "rgba(0, 0, 0, 0.08)", // shadow-only cards, no colored border
        success: "#10b981",  // emerald-500 — "Ready" badge
        warning: "#f59e0b",  // amber-500 — "Waiting" badge
        danger: "#ef4444",   // red-500 — destructive actions
        info: "#3b82f6",     // blue-500 — info banners

        // Backward compatibility
        brand: {
          50: "#eff6ff",
          100: "#dbeafe",
          200: "#bfdbfe",
          300: "#93c5fd",
          400: "#60a5fa",
          500: "#0070fc",
          600: "#005ecc",
          700: "#004db3",
          800: "#003c8c",
          900: "#002a66",
        },
      },
      borderRadius: {
        sm: "6px",   // chips, small badges
        md: "12px",  // default: inputs, buttons, small cards
        lg: "16px",  // cards, panels
        xl: "24px",  // drawers, modals
        "2xl": "20px",
        full: "9999px", // pill buttons, pill tabs, avatars
      },
      fontFamily: {
        sans: ["Inter", "system-ui", "-apple-system", "sans-serif"],
      },
      boxShadow: {
        xs: "0 1px 2px 0 rgb(0 0 0 / 0.04)",
        sm: "0 1px 3px 0 rgba(0, 0, 0, 0.06), 0 1px 2px -1px rgba(0, 0, 0, 0.04)",
        md: "0 2px 8px 0 rgba(0, 0, 0, 0.08)", // card shadow — matches image
        lg: "0 4px 16px 0 rgba(0, 0, 0, 0.08), 0 2px 6px -2px rgba(0, 0, 0, 0.04)",
        panel: "0 1px 4px 0 rgba(0, 0, 0, 0.08)", // right-panel / modal
      },
      backdropBlur: {
        xs: "2px",
      },
    },
  },
  plugins: [],
};

export default config;
