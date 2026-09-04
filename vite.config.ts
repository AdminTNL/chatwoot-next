import { defineConfig } from 'vite';
import ruby from 'vite-plugin-ruby';
import vue from '@vitejs/plugin-vue';
import { aliases, vueOptions } from './vite.shared';
import yaml from '@rollup/plugin-yaml';

export default defineConfig({
  plugins: [ruby(), vue(vueOptions), yaml()],
  css: {
    preprocessorOptions: {
      scss: {
        api: 'modern-compiler',
      },
    },
  },
  resolve: { alias: aliases },
  server: {
    // Under Docker the dev server runs in its own container and Rails proxies to
    // it as `vite`, a host name Vite's default host check rejects with a 403.
    // Only consulted by the dev server; `vite build` ignores it.
    allowedHosts: ['vite', 'localhost', '127.0.0.1'],
  },
});
