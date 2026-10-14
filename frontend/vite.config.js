import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// In development the API is reached through the same /api prefix used in
// production (nginx proxies /api/ -> backend), so no CORS configuration is needed.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: process.env.BACKEND_URL || 'http://localhost:8080',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ''),
      },
    },
  },
});
