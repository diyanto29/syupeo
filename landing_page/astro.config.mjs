// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

// https://astro.build/config
export default defineConfig({
  // Kita ubah ke statis agar bisa dihosting gratis di Firebase
  output: "static",
  vite: {
    plugins: [tailwindcss()]
  }
});