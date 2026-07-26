import { defineConfig } from 'vite';

export default defineConfig({
  // Dynamically set base: '/Warehouse-Inventory-System/' only for production build on GitHub Pages
  base: process.env.NODE_ENV === 'production' ? '/Warehouse-Inventory-System/' : '/',
  root: './',
  build: {
    outDir: '../dist'
  },
  server: {
    port: 3001,
    open: true
  }
});
