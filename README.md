# Local-first application template

Copier template for a local-first web application: the browser owns all data in
SQLite WASM persisted to the Origin Private File System (OPFS), routed through a
service worker. There is no hosted application backend, no account and no
synchronization.

## What a generated project contains

- Vite + TypeScript web application with Turbo and Stimulus.
- A service worker hosting a Hono router under `/local`.
- A dedicated database worker that owns SQLite WASM (OPFS SAH pool) through
  Drizzle.
- One task form and list proving the full path from the UI to durable storage.
- Chrome browser E2E and Node integration tests over the same service code.
- Service commands (`./make.sh`) and `mise` tasks for setup, development, build,
  format, lint, tests and end-to-end checks.

## Generate a project

```sh
copier copy --vcs-ref HEAD \
  --data project_name=my-app \
  --data app_title="My App" \
  . ../my-app
```

`project_name` must be lowercase kebab-case. It names the SQLite database, the
OPFS pool and the Web Lock that keeps database ownership single-tab.
`app_title` defaults to a title-cased form of the project name.

## Check the template

```sh
./make.sh test    # render a disposable project and assert its contents
./make.sh check   # render a project, then lint, test, build and browser-test it
```

`./make.sh test` renders from the committed revision, so commit template changes
before running it.

## Verified platform support

Chrome on desktop is tested. iOS WKWebView, offline reopening, multi-tab error
states, task editing and the native Rust bridge are not implemented yet and are
not claimed. See `template/docs/architecture/001-local-web-runtime.md` in a
generated project for the runtime boundaries that already exist.

## Prerequisites

- Node.js 24 with npm (pinned in `mise.toml`)
- Google Chrome or Playwright's Chromium for browser checks
- Copier 9.18 or newer
- No cloud account, database server, container runtime or signing identity

Deployment, hosting, iOS builds and releases are out of scope for this template
until those slices exist.

## License

MIT. See [LICENSE](LICENSE) and the generated project's
`app/THIRD-PARTY-NOTICES.md`.
