import { defineConfig } from 'vite';

export default defineConfig({
  base: '/Warehouse-Inventory-System/',
  build: {
    outDir: '../dist'
  },
  server: {
    port: 3001,
    open: true
  }
});
