# Local-first application

This application stores its data in the browser. A service worker routes local
requests to a database worker that owns SQLite WASM persisted in OPFS. There is
no account, no hosted application backend and no synchronization.

A Hotwire Native iOS shell loads the same web application from a configurable
HTTPS origin (a CDN in production, or a local tunnel during development). Task
logic and persistence stay in the web runtime on both platforms.

## Prerequisites

- Node.js 24 with npm (`mise.toml` pins it; any Node.js 24 installation works)
- Google Chrome, or Playwright's Chromium for the browser checks
- For the iOS simulator checks: macOS, Xcode with an iOS simulator runtime, and
  `cloudflared` on `PATH`

No database server, container runtime, cloud account or signing identity is
needed. The simulator build does not use a signing team.

## Commands

```sh
./make.sh setup_local   # install dependencies and the Playwright browser
./make.sh run_dev       # Vite development server on http://127.0.0.1:5173
./make.sh format        # write formatting
./make.sh lint          # formatting, ESLint and TypeScript checks (read-only)
./make.sh build         # type-check and build the static application
./make.sh test          # integration tests over the real services and SQLite
./make.sh test_e2e      # Chrome E2E against Vite dev and the static build
./make.sh build_ios     # build the iOS shell for the simulator
./make.sh test_ios      # tunnel + simulator UI flow, including offline relaunch
./make.sh check         # all of the above (native checks on macOS with Xcode)
```

The same commands are available as `mise run <task>` (`setup`, `dev`, `format`,
`lint`, `test`, `test:e2e`, `build:ios`, `test:ios`, `check`).

The simulator checks require a Cloudflare quick tunnel because WKWebView needs an
HTTPS origin, and because service workers only work when navigation is limited
to app-bound domains. `./make.sh test_ios` starts the tunnel itself; the URL is
written to the gitignored `app/.local-ios/origin.json` and is never a template
default.

## How a request reaches storage

1. `app/index.html` loads the application and a Turbo frame named `tasks`.
2. `app/src/main.ts` registers the service worker, waits until it controls the
   page, then points the frame at `/local/tasks`.
3. The service worker hosts a Hono router under `/local` and forwards database
   requests to the page that made them.
4. `app/src/database.ts` relays those messages to the database worker.
5. `app/worker/database.ts` owns SQLite WASM (OPFS SAH pool) through Drizzle and
   answers from `app/worker/services/tasks.ts`.
6. Hono renders the returned task list back into the Turbo frame.

Only one tab can own the database. A second tab shows an error instead of
falling back to volatile storage.

The footer shows a runtime status line with the capabilities the current
WebView actually reports: secure context, cross-origin isolation, service worker
control, Web Locks, OPFS and the SQLite version opened by the database worker.

## iOS shell

- `native/ios/LocalFirstApp` is a Hotwire Native shell that loads
  `WEB_ORIGIN` and allows only that origin's hostname (`WKAppBoundDomains`).
- `native/ios/LocalFirstAppUITests` runs the simulator flows: create a task,
  check the runtime status, use native back navigation, then relaunch with the
  origin unreachable and expect the saved task from cached UI and OPFS.
- The `web_origin`, `app_bound_domain`, `ios_bundle_identifier` and
  `ios_display_name` answers are set at generation time. Change `web_origin` for
  a real CDN; `make.sh` derives the app-bound domain from it.

## Data and platform notes

- Data lives in this origin's OPFS. Chrome and iOS WKWebView use separate
  stores; nothing is shared between them.
- The iOS shell reopens after an initial online load even when the origin is
  unreachable, because the service worker serves the cached application. A
  first launch without network is not supported.
- Clearing site data or the app container deletes the tasks. There is no backup
  or export yet.
- Chrome and the iOS Simulator are the tested platforms. Physical iOS devices
  and a real CDN deployment are not verified. Safari and Firefox are not
  claimed.

## Documentation

- `docs/architecture/001-local-web-runtime.md` — runtime boundaries and storage.
- `docs/architecture/002-ios-wkwebview-loading.md` — remote origin, app-bound
  domains and the offline relaunch.
- `AGENTS.md` — repository rules for human and automated contributors.
- `app/THIRD-PARTY-NOTICES.md` — bundled third-party components.
