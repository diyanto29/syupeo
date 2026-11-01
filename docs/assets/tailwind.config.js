/** @type {import('tailwindcss').Config} */
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#0070fc',
          hover: '#005ecc',
          50: '#eff6ff',
          100: '#dbeafe',
          500: '#0070fc',
          600: '#005ecc',
          700: '#004db3',
        },
        secondary: {
          DEFAULT: '#ba8c02',
          50: '#fefce8',
          500: '#ba8c02',
          600: '#a17800',
        },
        accent: {
          DEFAULT: '#548ce0',
          500: '#548ce0',
        },
        surface: {
          DEFAULT: '#ffffff',
          subtle: '#f8fafc',
        },
        text: {
          DEFAULT: '#1a1a1a',
          muted: '#64748b',
        },
        border: 'rgba(26, 26, 26, 0.12)',
        success: '#3396fa',
        warning: '#ba8c02',
        danger: '#3294f5',
        info: '#548ce0',
      },
      borderRadius: {
        sm: '4px',
        md: '8px',
        lg: '16px',
        xl: '24px',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
    },
  },
};

