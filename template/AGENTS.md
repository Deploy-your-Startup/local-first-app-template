# Repository rules

Local-first task application. The browser owns the data; there is no hosted
application backend. A Hotwire Native iOS shell loads the same web runtime from
a configurable HTTPS origin.

## Commands

Use `./make.sh` (or the equivalent `mise` task) for everything:

- `./make.sh setup_local` — install dependencies and the Playwright browser
- `./make.sh run_dev` — Vite development server
- `./make.sh format` — write formatting
- `./make.sh lint` — read-only formatting, ESLint and TypeScript checks
- `./make.sh build` — type-check and build the static application
- `./make.sh test` — integration tests over the real services and SQLite
- `./make.sh test_e2e` — Chrome E2E against the dev server and static build
- `./make.sh build_ios` — build the Hotwire Native shell for the simulator
- `./make.sh test_ios` — Cloudflare Tunnel + simulator UI flow, including the
  offline relaunch
- `./make.sh check` — all of the above; native checks need macOS with Xcode

Run lint and the relevant tests before claiming work is done. A passing
development run is not evidence for the static build, a Chrome pass is not
evidence for iOS, and an iOS build is not evidence for the offline relaunch.

## Boundaries

- Task logic and persistence belong to TypeScript services in
  `app/worker/services/` and `app/shared/`. Do not add a native database or move
  task CRUD into native code. Native code owns navigation only.
- The database is owned by exactly one tab through the OPFS SAH pool and a Web
  Lock. Never add a volatile fallback.
- The service worker hosts the local HTTP surface with Hono under `/local`. The
  page, service worker and database worker exchange typed messages declared in
  `app/shared/`.
- The initial schema is declared once in `app/shared/tasks.ts` and used by both
  the database worker and the integration tests.
- OPFS requires a cross-origin isolated context. Keep the
  `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers on the
  dev and preview servers; the Cloudflare Tunnel passes them through for the
  simulator.
- SQLite WASM lives in `app/public/sqlite/` with its upstream notice. Do not
  bundle or edit it.
- Service workers in WKWebView require
  `WKWebViewConfiguration.limitsNavigationsToAppBoundDomains` and a
  `WKAppBoundDomains` hostname equal to the web origin. Keep both derived from
  the single `WEB_ORIGIN` value (`make.sh` and `app/scripts/web-origin.ts`); the
  shell refuses to start when they disagree.
- Do not commit a tunnel URL, a certificate or a signing identity. The simulator
  harness writes its transient origin to the gitignored `app/.local-ios/`.
- The iOS shell loads the web runtime remotely. Never bundle web assets or add a
  first-launch-offline requirement.

## Tests

- Start behavior changes with an executable integration or E2E scenario.
- Use the real services, the real service worker and real SQLite. Do not mock
  this repository's own code to make a check pass.
- `app/tests/integration/` runs on `node --test` against `node:sqlite` through
  the same Drizzle service code the browser uses.
- `app/tests/e2e/` runs Playwright against a real Chrome context, once against
  the Vite dev server and once against the static build.
- `native/ios/LocalFirstAppUITests/` runs on the iOS Simulator. `OnlineFlowTests`
  proves the web runtime and native navigation; `OfflineRelaunchTests` proves
  cached reopening after `scripts/ios-simulator.mjs` made the origin
  unreachable. Both are required; neither replaces a Chrome or static check.
- The harness makes the origin unreachable instead of disabling the simulator's
  network. Physical devices remain untested.
- Capabilities that are not implemented must not be described as supported.
