#!/usr/bin/env node
// Serve the static production build over HTTPS with the cross-origin isolation
// headers the application requires. This stands in for a CDN during local
// development and in the iOS simulator checks; it does not provision hosting.
//
// GET /__control/ping      -> "ok"
// GET /__control/offline   -> stop answering content requests (offline test)
// GET /__control/online    -> resume answering content requests
import { createServer } from "node:https";
import { existsSync, readFileSync, statSync } from "node:fs";
import { extname, join, normalize, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const appRoot = resolve(fileURLToPath(new URL("..", import.meta.url)));
const args = process.argv.slice(2);

function argument(name, fallback) {
  const index = args.indexOf(`--${name}`);
  return index === -1 ? fallback : args[index + 1];
}

const port = Number(argument("port", process.env.PORT ?? "8443"));
const root = resolve(appRoot, argument("root", "dist"));
const certDir = resolve(appRoot, ".local-https");

for (const file of ["ca.pem", "server.pem", "server.key"]) {
  if (!existsSync(join(certDir, file))) {
    console.error(
      `Missing ${join(certDir, file)}. Run scripts/make-dev-cert.sh first.`,
    );
    process.exit(1);
  }
}

if (!existsSync(join(root, "index.html"))) {
  console.error(
    `Missing ${join(root, "index.html")}. Run \`npm run build\` first.`,
  );
  process.exit(1);
}

// Every response carries the same isolation headers as Vite dev and preview.
const isolationHeaders = {
  "Cross-Origin-Opener-Policy": "same-origin",
  "Cross-Origin-Embedder-Policy": "require-corp",
  "X-Content-Type-Options": "nosniff",
};

const contentTypes = new Map([
  [".css", "text/css; charset=utf-8"],
  [".html", "text/html; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".mjs", "text/javascript; charset=utf-8"],
  [".svg", "image/svg+xml"],
  [".wasm", "application/wasm"],
  [".webmanifest", "application/manifest+json"],
]);

let contentAvailable = true;

function send(response, status, headers, body) {
  response.writeHead(status, { ...isolationHeaders, ...headers });
  response.end(body);
}

const server = createServer(
  {
    cert: readFileSync(join(certDir, "server.pem")),
    key: readFileSync(join(certDir, "server.key")),
  },
  (request, response) => {
    const url = new URL(request.url ?? "/", `https://${request.headers.host}`);

    if (url.pathname === "/__control/ping") {
      return send(response, 200, { "Content-Type": "text/plain" }, "ok");
    }

    if (url.pathname === "/__control/offline") {
      contentAvailable = false;
      return send(response, 200, { "Content-Type": "text/plain" }, "offline");
    }

    if (url.pathname === "/__control/online") {
      contentAvailable = true;
      return send(response, 200, { "Content-Type": "text/plain" }, "online");
    }

    if (!contentAvailable) {
      // Refuse like an unreachable origin: the service worker must answer from
      // its cache without a network response.
      return send(response, 503, { "Content-Type": "text/plain" }, "offline");
    }

    const pathname = decodeURIComponent(url.pathname);
    const candidate = normalize(join(root, pathname));
    if (!candidate.startsWith(root)) {
      return send(response, 403, { "Content-Type": "text/plain" }, "forbidden");
    }

    let file = candidate;
    if (existsSync(file) && statSync(file).isDirectory()) {
      file = join(file, "index.html");
    }

    if (!existsSync(file) || !statSync(file).isFile()) {
      return send(response, 404, { "Content-Type": "text/plain" }, "not found");
    }

    const type = contentTypes.get(extname(file)) ?? "application/octet-stream";
    const headers = { "Content-Type": type };

    if (pathname === "/sw.js") {
      headers["Service-Worker-Allowed"] = "/";
      headers["Cache-Control"] = "no-cache";
    }

    send(response, 200, headers, readFileSync(file));
  },
);

server.listen(port, "127.0.0.1", () => {
  console.log(`serving ${root} at https://localhost:${port}`);
});
