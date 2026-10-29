import { defineConfig } from "vite";
import { VitePWA } from "vite-plugin-pwa";

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
    // The iOS simulator harness exposes this dev server through a Cloudflare
    // quick tunnel. Vite rejects unknown Host headers, so allow the tunnel
    // domain (localhost is always allowed).
    allowedHosts: [".trycloudflare.com"],
  },
  preview: {
    host: "127.0.0.1",
    port: 4173,
    strictPort: true,
    headers: crossOriginIsolationHeaders,
    allowedHosts: [".trycloudflare.com"],
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
