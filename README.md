# Local-first application template

Copier template for a local-first web application: the browser owns all data in
SQLite WASM persisted to the Origin Private File System (OPFS), routed through a
service worker. A Hotwire Native iOS shell loads the same web runtime from a
configurable HTTPS origin. There is no hosted application backend, no account
and no synchronization.

## What a generated project contains

- Vite + TypeScript web application with Turbo and Stimulus.
- A service worker hosting a Hono router under `/local`, precaching the static
  build so the application can reopen offline after an initial online load.
- A dedicated database worker that owns SQLite WASM (OPFS SAH pool) through
  Drizzle, plus a visible runtime status line.
- One task form and list proving the full path from the UI to durable storage.
- A Hotwire Native iOS shell with app-bound domains, a native About screen and
  simulator UI tests that cover the offline relaunch.
- Chrome browser E2E, Node integration tests and iOS simulator tests over the
  same service code.
- Service commands (`./make.sh`) and `mise` tasks for setup, development, build,
  format, lint, tests, native build and end-to-end checks.

## Generate a project

```sh
copier copy --vcs-ref HEAD \
  --data project_name=my-app \
  --data app_title="My App" \
  --data ios_bundle_identifier=com.example.myapp \
  --data web_origin=https://tasks.example.com \
  . ../my-app
```

`project_name` must be lowercase kebab-case. It names the SQLite database, the
OPFS pool and the Web Lock that keeps database ownership single-tab.
`app_title` defaults to a title-cased form of the project name;
`ios_display_name` defaults to `app_title`; `ios_bundle_identifier` defaults to
`com.example.<project_name>`. `app_bound_domain` is derived from `web_origin`,
so change the origin instead of the hostname. `web_origin` defaults to
`http://localhost:4173` for local simulator runs.

## Check the template

```sh
./make.sh test    # render a disposable project and assert its contents
./make.sh check   # render a project, then lint, test, build and browser-test it
```

`./make.sh test` renders from the committed revision, so commit template changes
before running it. The rendered project's `./make.sh test_ios` additionally
requires macOS, Xcode with a simulator runtime and `cloudflared`; it is not part
of the Linux CI job.

## Verified platform support

Chrome on desktop and the iOS Simulator are tested, including reopening the
application after the configured origin became unreachable. Physical iOS
devices, a real CDN deployment, multi-tab error states, task editing and the
native Rust bridge are not implemented or verified yet and are not claimed. See
`template/docs/architecture/001-local-web-runtime.md` and
`002-ios-wkwebview-loading.md` in a generated project.

## Prerequisites

- Node.js 24 with npm (pinned in `mise.toml`)
- Google Chrome or Playwright's Chromium for browser checks
- Copier 9.18 or newer
- For the iOS simulator checks: macOS, Xcode and `cloudflared`
- No cloud account, database server, container runtime or signing identity

Deployment, hosting, App Store distribution and releases are out of scope for
this template until those slices exist.

## License

MIT. See [LICENSE](LICENSE) and the generated project's
`app/THIRD-PARTY-NOTICES.md`.
