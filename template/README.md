# Local-first application

This application stores its data in the browser. A service worker routes local
requests to a database worker that owns SQLite WASM persisted in OPFS. There is
no account, no hosted application backend and no synchronization.

## Prerequisites

- Node.js 24 with npm (`mise.toml` pins it; any Node.js 24 installation works)
- Google Chrome, or Playwright's Chromium for the browser checks

No database server, container runtime, cloud account or signing identity is
needed.

## Commands

```sh
./make.sh setup_local   # install dependencies and the Playwright browser
./make.sh run_dev       # Vite development server on http://127.0.0.1:5173
./make.sh format        # write formatting
./make.sh lint          # formatting, ESLint and TypeScript checks (read-only)
./make.sh build         # type-check and build the static application
./make.sh test          # integration tests over the real services and SQLite
./make.sh test_e2e      # Chrome E2E against Vite dev and the static build
./make.sh check         # lint, test, build and browser checks together
```

The same commands are available as `mise run <task>` (`setup`, `dev`, `format`,
`lint`, `test`, `test:e2e`, `check`).

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

## Data and platform notes

- Data lives in this browser profile's OPFS for this origin. Chrome and iOS
  WKWebView use separate stores; nothing is shared between them.
- Clearing site data deletes the tasks. There is no backup or export yet.
- Chrome is the tested browser. Other browsers, iOS, offline reopening and
  multi-tab recovery are not implemented yet.

## Documentation

- `docs/architecture/001-local-web-runtime.md` — runtime boundaries and the
  decisions behind them.
- `AGENTS.md` — repository rules for human and automated contributors.
- `app/THIRD-PARTY-NOTICES.md` — bundled third-party components.
