# Architecture decision 001: local web runtime boundaries

## Status

Accepted for the first vertical slice (create and list tasks in Chrome).

## Context

The application must persist data without a hosted backend, on a stack that also
supports a native shell later. The browser is the only place that owns user
data; native code may gain capabilities later but never a second database.

## Decision

Requests take one path, in this order:

```
index.html → src/main.ts → service worker (Hono, /local)
           → page message relay (src/database.ts)
           → database worker (worker/database.ts)
           → Drizzle (worker/services/tasks.ts)
           → SQLite WASM / OPFS SAH pool
```

- The service worker is the HTTP surface. It mounts a Hono application at
  `/local` and answers with HTML fragments for Turbo frames. It never touches
  SQLite itself: a service worker cannot access OPFS reliably and must not own
  durability.
- A dedicated worker owns the database for the tab's lifetime. Messages and
  responses are typed in `shared/tasks.ts` and carried over `MessageChannel`
  ports.
- SQLite is persisted through the OPFS SAH pool
  (`installOpfsSAHPoolVfs`) because it keeps a real database file in the Origin
  Private File System and supports multiple connections without a volatile
  fallback.
- Drizzle maps the schema. The table definition and the `CREATE TABLE`
  statement live together in `shared/tasks.ts` so the worker and the integration
  tests cannot drift apart.
- One tab owns the database: the worker holds an exclusive Web Lock for its
  lifetime. A second tab fails fast with an explicit message rather than
  producing a second writer.
- OPFS needs a cross-origin isolated context, so the dev and preview servers send
  `Cross-Origin-Opener-Policy: same-origin` and
  `Cross-Origin-Embedder-Policy: require-corp`.
- The SQLite runtime is served as a static asset from `public/sqlite/3.54.1/`
  and imported by URL, so the same files work under the Vite dev server and in
  the static build. The pinned version is verified at startup.

## Consequences

- The application works from a static build with no server-side logic, which is
  what a CDN-served shell will load later.
- Task logic stays in TypeScript services for every platform; a future native
  shell reuses the same web runtime instead of adding a native database.
- The single-owner lock is a hard requirement, not a best effort. Error states
  for contended storage must stay visible and must never pretend a write
  succeeded.
- Service-worker caching is proven in the iOS WKWebView (ADR 002); the browser
  offline and multi-tab behaviours remain later slices.
