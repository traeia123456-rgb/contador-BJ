// @ts-check
import { defineConfig } from 'astro/config';
import vercel from '@astrojs/vercel/serverless';

import tailwindcss from '@tailwindcss/vite';

// https://astro.build/config
export default defineConfig({
  devToolbar: { enabled: false },
  adapter: vercel(),
  output: 'server',
  vite: {
    plugins: [tailwindcss()]
  }
});