# Repository rules

Local-first task application. The browser owns the data; there is no hosted
application backend.

## Commands

Use `./make.sh` (or the equivalent `mise` task) for everything:

- `./make.sh setup_local` — install dependencies and the Playwright browser
- `./make.sh run_dev` — Vite development server
- `./make.sh format` — write formatting
- `./make.sh lint` — read-only formatting, ESLint and TypeScript checks
- `./make.sh build` — type-check and build the static application
- `./make.sh test` — integration tests over the real services and SQLite
- `./make.sh test_e2e` — Chrome E2E against the dev server and static build
- `./make.sh check` — all of the above

Run lint and the relevant tests before claiming work is done. A passing
development run is not evidence for the static build and a Chrome pass is not
evidence for iOS.

## Boundaries

- Task logic and persistence belong to TypeScript services in
  `app/worker/services/` and `app/shared/`. Do not add a native database or move
  task CRUD into native code.
- The database is owned by exactly one tab through the OPFS SAH pool and a Web
  Lock. Never add a volatile fallback.
- The service worker hosts the local HTTP surface with Hono under `/local`. The
  page, service worker and database worker exchange typed messages declared in
  `app/shared/`.
- The initial schema is declared once in `app/shared/tasks.ts` and used by both
  the database worker and the integration tests.
- OPFS requires a cross-origin isolated context. Keep the
  `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers on the
  dev and preview servers.
- SQLite WASM lives in `app/public/sqlite/` with its upstream notice. Do not
  bundle or edit it.

## Tests

- Start behavior changes with an executable integration or E2E scenario.
- Use the real services, the real service worker and real SQLite. Do not mock
  this repository's own code to make a check pass.
- `app/tests/integration/` runs on `node --test` against `node:sqlite` through
  the same Drizzle service code the browser uses.
- `app/tests/e2e/` runs Playwright against a real Chrome context, once against
  the Vite dev server and once against the static build.
- Capabilities that are not implemented must not be described as supported.
