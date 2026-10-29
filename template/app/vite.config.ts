import { defineConfig } from "vite";
import { VitePWA } from "vite-plugin-pwa";
import { resolve } from "node:path";

// OPFS requires a cross-origin isolated context. Keep these headers identical
// for development and for the static build served by `vite preview`.
const crossOriginIsolationHeaders = {
  "Cross-Origin-Opener-Policy": "same-origin",
  "Cross-Origin-Embedder-Policy": "require-corp",
};

export default defineConfig({
  server: {
    host: "127.0.0.1",
    port: 5173,
    strictPort: true,
    headers: crossOriginIsolationHeaders,
  },
  preview: {
    host: "127.0.0.1",
    port: 4173,
    strictPort: true,
    headers: crossOriginIsolationHeaders,
  },
  build: {
    rollupOptions: {
      input: {
        main: resolve(import.meta.dirname, "index.html"),
        about: resolve(import.meta.dirname, "about.html"),
      },
    },
  },
  plugins: [
    VitePWA({
      strategies: "injectManifest",
      srcDir: "worker",
      filename: "sw.ts",
      injectRegister: false,
      manifest: false,
      injectManifest: {
        globPatterns: ["**/*.{js,mjs,css,html,wasm}"],
      },
      devOptions: {
        enabled: true,
        type: "module",
      },
    }),
  ],
});
