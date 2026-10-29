# Local-first application

This application stores its data in the browser. A service worker routes local
requests to a database worker that owns SQLite WASM persisted in OPFS. There is
no account, no hosted application backend and no synchronization. An iOS
Hotwire Native shell loads the same web application from an HTTPS origin.

## Prerequisites

- Node.js 24 with npm (`mise.toml` pins it; any Node.js 24 installation works)
- Google Chrome, or Playwright's Chromium for the browser checks
- Xcode with an iOS simulator runtime for the native checks
  (`/Applications/Xcode.app`, selected with `xcode-select`, or `DEVELOPER_DIR`)
- `openssl` and `curl` for the local HTTPS test server

No database server, container runtime, cloud account or signing identity is
needed. Native checks run on the simulator only.

## Commands

```sh
./make.sh setup_local   # install dependencies and the Playwright browser
./make.sh run_dev       # Vite development server on http://127.0.0.1:5173
./make.sh format        # write formatting
./make.sh lint          # formatting, ESLint, TypeScript and shell syntax checks
./make.sh build         # type-check and build the static application
./make.sh test          # integration tests over the real services and SQLite
./make.sh test_e2e      # Chrome E2E: dev, static preview and HTTPS static server
./make.sh build_ios     # build the Hotwire Native shell for the simulator
./make.sh test_ios      # simulator UI test: online load, offline relaunch
./make.sh check         # all of the above
```

The same commands are available as `mise run <task>` (`setup`, `dev`, `format`,
`lint`, `test`, `test:e2e`, `ios:build`, `ios:test`, `check`).

The iOS checks start `app/scripts/serve-static-https.mjs` on
`https://localhost:8443`, install its throwaway CA into the chosen simulator and
run `xcodebuild test`. They do not provision hosting. Select a simulator with
`IOS_SIMULATOR_UDID` or accept the first available iPhone.

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

- Data lives in this browser or WebView profile's OPFS for the loaded origin.
  Chrome and iOS WKWebView use separate stores; nothing is shared between them.
- Clearing site data deletes the tasks. There is no backup, export or
  synchronization.
- Chrome on desktop and iOS WKWebView in the simulator are the tested platforms.
  Safari, Firefox, physical iOS devices, hosting and app-store distribution are
  not tested.
- Offline reopening is tested on Chrome after a production build and in the iOS
  simulator after the first online load. The simulator check makes the app origin
  unreachable; it does not switch the whole host network off.
- App-bound domains are listed in `native/ios/LocalFirstApp/Info.plist` and
  enabled. WKWebView only exposes service workers to app-bound domains. Add the
  CDN host to `WKAppBoundDomains` when hosting exists; keep `localhost` only for
  local development.

## Documentation

- `docs/architecture/001-local-web-runtime.md` — runtime boundaries and the
  decisions behind them.
- `docs/architecture/002-ios-webview-runtime.md` — the iOS shell, origin,
  app-bound domains and simulator checks.
- `AGENTS.md` — repository rules for human and automated contributors.
- `app/THIRD-PARTY-NOTICES.md` — bundled third-party components.
