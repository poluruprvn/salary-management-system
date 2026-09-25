import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import path from 'node:path'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@': path.resolve(import.meta.dirname, './src'),
    },
  },
  test: {
    environment: 'jsdom',
    // West of UTC, so a date printed in local time rather than UTC comes out a day early and fails.
    env: { TZ: 'America/Los_Angeles' },
    setupFiles: ['./src/test/setup.ts'],
  },
})
