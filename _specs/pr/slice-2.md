## Slice 2: save and reopen one task in iOS WKWebView

> **Historical draft — rolled back.** Slice 1 (`f075d04`) is the last completed
> slice. The implementation and test results below describe a previous attempt,
> not the active checkout. All checked items below are historical, not current
> completion. Reimplement and revalidate Slice 2 before reusing this draft.
> The current checklist is [../todo.md](../todo.md). Remote PR state has not
> been reverified.

Stacked on `slice-1-chrome-task-persistence`. Predecessor: #1. Base branch is
the slice 1 branch until that PR merges; retarget to `main` afterwards.

Plan, checklist and extraction evidence now live in this repository's `_specs/`.

### Demonstrated flow

Generated Hotwire Native shell → local HTTPS origin serving the static build →
the same service worker/Hono/database-worker/SQLite WASM/OPFS path as Chrome →
create a task → terminate the app → make the origin unreachable → relaunch →
the task is shown from the cached UI and durable OPFS storage → native
navigation to About and back.

The About page reports the actual WKWebView capabilities. The simulator test
asserts `Runtime: all available`, which covers cross-origin isolation, service
worker control, Web Locks and OPFS access.

### What changed

- Copier answers `ios_bundle_identifier` and `web_origin`; display name, bundle
  identifier, origin and app-bound domains are rendered into the iOS shell.
- `native/ios/` Hotwire Native shell (UIKit scene lifecycle): configurable HTTPS
  origin, `WKAppBoundDomains`, native back navigation and an About route.
- Simulator UI test: online load, create task, terminate, origin offline,
  relaunch, read the saved task, check runtime capabilities, navigate back.
- `app/scripts/serve-static-https.mjs` and `make-dev-cert.sh`: a local HTTPS
  static origin with COOP/COEP and a throwaway CA. No hosting is provisioned and
  no certificate is committed.
- Chrome E2E now also runs against the HTTPS static origin and covers offline
  reload and the About runtime diagnostic.
- Service commands: `build_ios`, `test_ios`; `check` includes them. `mise` tasks
  `ios:build` and `ios:test`.
- Template-owned ADR `docs/architecture/002-ios-webview-runtime.md`; README,
  AGENTS and render checks updated.

### Test results (local, macOS)

Run from the template repository at `7d7c76e`:

- `./make.sh test` → pass: rendered project contains the native shell, no
  placeholders, no source branding or personal paths.
- Generated project `./make.sh check` → pass:
  - `./make.sh lint` → pass (Prettier, ESLint, three TypeScript projects, shell
    syntax).
  - `./make.sh test` → pass, 6/6 integration tests over real `node:sqlite`.
  - `./make.sh build` → pass.
  - `./make.sh test_e2e` → pass: 4/4 Chrome dev (About), 6/6 static (including
    offline reload) and 6/6 HTTPS static.
  - `./make.sh build_ios` → `** BUILD SUCCEEDED **`.
  - `./make.sh test_ios` → `** TEST SUCCEEDED **`: 1/1 XCUITest in the iOS 27.1
    simulator (iPhone) in 27.9 s.
- Factory `_specs/checks.sh` → pass, including slice 0 traces, render checks and
  the full generated-project run.
- `node --test _specs/run-loop.test.mjs _specs/checks.test.mjs` → 6/6 pass.
- GitHub Actions run `40892667531` (Ubuntu, Node.js 24) passed every step:
  render assertions, generated-project lint, 6/6 integration, static build and
  4/4 dev + 6/6 static + 6/6 HTTPS Chrome E2E. Native checks are local because
  GitHub's Linux runner has no iOS simulator.

Environment: Xcode 27.1 / iOS 27.1 simulator runtime, Node.js 23.11 with npm
(the project pins Node.js 24), Copier 9.19.1.

### How to validate

```sh
cd projects/tooling/local-first-app-template   # or a clone
copier copy --vcs-ref HEAD --data project_name=my-app . /tmp/my-app
cd /tmp/my-app
./make.sh setup_local
./make.sh check
```

`./make.sh check` needs Xcode with an iOS simulator runtime. The iOS scripts
select the first available iPhone unless `IOS_SIMULATOR_UDID` is set, install the
throwaway CA into that simulator and start the HTTPS server on port 8443. On a
machine where `xcode-select` points at Command Line Tools, set `DEVELOPER_DIR`
to a full Xcode installation.

### Skips, gaps and limitations

- **Offline method:** the check makes the app origin unreachable. The simulator
  shares the host network stack and `simctl` has no airplane mode, so the whole
  host network is not switched off. This is recorded in ADR 002; it proves cached
  UI and durable storage but not global network loss.
- **App-bound domains:** WKWebView only exposes service workers to app-bound
  domains. The flag is on and `localhost` is allowed; a deployed CDN host must be
  added to `WKAppBoundDomains`. The restriction is not tested against a real
  registrable domain because hosting is out of scope.
- **Not tested:** physical iOS devices, device signing, App Store distribution,
  CDN hosting, Safari, Firefox, and the native Rust bridge (slice 3). CI remains
  Linux and runs the browser/render checks; the simulator check is local.
- **Existing warning:** npm reports ESLint engine-range warnings because this
  machine runs Node.js 23.11 while the project pins Node.js 24. All checks pass.

### Checklist status

- [x] Parameterize display name and bundle identifier; build without personal
      signing identities or hardcoded Xcode paths.
- [x] Configure a web origin and app-bound domains for Vite/static HTTPS.
- [x] Prove secure context, service-worker control, database workers, Web Locks
      and OPFS inside the actual WKWebView configuration.
- [x] Reuse the same TypeScript services and schema; no native persistence.
- [x] Simulator UI E2E: load online, create, terminate, origin offline, relaunch,
      observe the saved task.
- [x] Exercise native navigation/back behavior.
- [x] Document origin, caching and storage choices in an ADR; expose native
      build/simulator commands.
- [x] No substitution with native SQLite, bundled assets or online-only loading.

Not merged. No force-push was used.
