# Repository rules

Local-first task application. The browser owns the data; there is no hosted
application backend. An iOS shell loads the same web runtime from a remote
origin.

## Commands

Use `./make.sh` (or the equivalent `mise` task) for everything:

- `./make.sh setup_local` — install dependencies and the Playwright browser
- `./make.sh run_dev` — Vite development server
- `./make.sh format` — write formatting
- `./make.sh lint` — read-only formatting, ESLint, TypeScript and shell checks
- `./make.sh build` — type-check and build the static application
- `./make.sh test` — integration tests over the real services and SQLite
- `./make.sh test_e2e` — Chrome E2E against dev, the static build and HTTPS
- `./make.sh build_ios` — build the Hotwire Native shell for the simulator
- `./make.sh test_ios` — simulator UI checks against the HTTPS static build
- `./make.sh check` — all of the above

Run lint and the relevant tests before claiming work is done. A passing
development run is not evidence for the static build, a Chrome pass is not
evidence for iOS, and a simulator pass is not evidence for a physical device.

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
  dev, preview and HTTPS test servers.
- SQLite WASM lives in `app/public/sqlite/` with its upstream notice. Do not
  bundle or edit it.
- The iOS shell loads the web app from the `web_origin` HTTPS URL. Do not bundle
  web assets, add a native database, or make offline first launch a requirement.
- Keep local certificates in `app/.local-https/` (gitignored). Never commit
  certificates, signing identities or team identifiers.

## Tests

- Start behavior changes with an executable integration or E2E scenario.
- Use the real services, the real service worker and real SQLite. Do not mock
  this repository's own code to make a check pass.
- `app/tests/integration/` runs on `node --test` against `node:sqlite` through
  the same Drizzle service code the browser uses.
- `app/tests/e2e/` runs Playwright against a real Chrome context: the Vite dev
  server, the static build and the local HTTPS server.
- `native/ios/LocalFirstAppUITests/` runs XCUITest in the simulator. It proves
  the actual WKWebView runtime, offline relaunch and native back navigation.
- Capabilities that are not implemented must not be described as supported.
