# Local-first application template

Copier template for a local-first web application: the browser owns all data in
SQLite WASM persisted to the Origin Private File System (OPFS), routed through a
service worker. There is no hosted application backend, no account and no
synchronization. A generated Hotwire Native shell loads the same web application
from an HTTPS origin on iOS.

## What a generated project contains

- Vite + TypeScript web application with Turbo and Stimulus.
- A service worker hosting a Hono router under `/local`.
- A dedicated database worker that owns SQLite WASM (OPFS SAH pool) through
  Drizzle.
- One task form and list proving the full path from the UI to durable storage.
- An About page that reports whether the WebView provides cross-origin
  isolation, service workers, Web Locks and OPFS.
- A Hotwire Native iOS shell with configurable display name, bundle identifier
  and HTTPS web origin, plus native navigation and back.
- Chrome browser E2E, a local HTTPS static origin, Node integration tests over
  the same service code and an iOS simulator UI test.
- Service commands (`./make.sh`) and `mise` tasks for setup, development, build,
  format, lint, tests and end-to-end checks.

## Generate a project

```sh
copier copy --vcs-ref HEAD \
  --data project_name=my-app \
  --data app_title="My App" \
  --data ios_bundle_identifier=com.example.myapp \
  --data web_origin=https://localhost:8443 \
  . ../my-app
```

`project_name` must be lowercase kebab-case. It names the SQLite database, the
OPFS pool and the Web Lock that keeps database ownership single-tab.
`app_title` defaults to a title-cased form of the project name.
`ios_bundle_identifier` defaults to `com.example.<project_name>`. `web_origin`
defaults to the local HTTPS test server; point it at the CDN origin once
hosting exists.

## Check the template

```sh
./make.sh test    # render a disposable project and assert its contents
./make.sh check   # render a project, then run all of its checks
```

`./make.sh test` renders from the committed revision, so commit template changes
before running it. `./make.sh check` needs Node.js, Chrome/Chromium and Xcode with
an iOS simulator runtime. The repository's CI runs the rendering, lint,
integration, build and Chrome checks on Linux; the iOS checks are local because
GitHub-hosted Linux runners have no simulator.

## Verified platform support

- Chrome on desktop: tasks, reload and offline reopening after a production
  build, over HTTP and the local HTTPS static server.
- iOS WKWebView in the simulator: the same web runtime, task creation, offline
  relaunch from cached UI and OPFS, and native navigation/back.
- Safari, Firefox, physical iOS devices, hosting, app-bound enforcement against a
  real domain and the native Rust bridge are not implemented or claimed.

## Prerequisites

- Node.js 24 with npm (pinned in `mise.toml`)
- Google Chrome, or Playwright's Chromium for browser checks
- Copier 9.18 or newer
- Xcode with an iOS simulator runtime for native checks
- No cloud account, database server, container runtime or signing identity

Deployment, hosting, device signing and releases are out of scope for this
template until those slices exist.

## License

MIT. See [LICENSE](LICENSE) and the generated project's
`app/THIRD-PARTY-NOTICES.md`.
