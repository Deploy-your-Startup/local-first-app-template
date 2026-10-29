# Slice 2 — save and reopen one task in iOS WKWebView

Source plan: [`_specs/local-first-app-template-plan.md`](../local-first-app-template-plan.md).
Checklist: slice 2 in [`_specs/todo.md`](../todo.md).

**Slice:** 2 of 10 — *Save and reopen one task in iOS WKWebView using the web
runtime*.
**Predecessor:** `slice-1-chrome-task-persistence` (PR #1). This PR targets that
branch.
**Status:** draft. All code and checks are in place; one checklist item that
requires the Xcode MCP approval in the Xcode UI could not be completed in this
non-interactive session (see below).

## What changed

```
copier.yml                         + ios_display_name, ios_bundle_identifier,
                                     web_origin, app_bound_domain
template/app
  shared/runtime.ts                runtime facts + status text (new)
  src/main.ts                      renders the observed runtime status
  src/database.ts                  database-diagnostics round trip
  worker/database.ts               reports the opened SQLite version
  worker/sw.ts                     NavigationRoute to the precached index.html
  scripts/web-origin.ts            origin/hostname rule (tested)
  scripts/ios-simulator.mjs        static build + Cloudflare Tunnel + XCUITest
  vite.config.ts                   allow the tunnel Host header
  tests/integration/runtime.test.ts, web-origin.test.ts
  tests/e2e/tasks.spec.ts          status-line scenario
template/native/ios
  LocalFirstApp.xcodeproj          committed Xcode project, Hotwire Native 1.3.1
  LocalFirstApp/                   UIKit scene shell, app-bound domains,
                                   native About screen, Info.plist
  LocalFirstAppUITests/            OnlineFlowTests + OfflineRelaunchTests
template/make.sh, mise.toml        build_ios / test_ios, check includes them
template/docs/                     ADR 002, updated ADR 001, README, AGENTS
tests/render_test.sh               native output, answer derivation, tunnel
                                   URL/certificate neutrality
.github/workflows/                 native checks documented as local-only
_specs/*                           checks, todo, scratchpad, this PR body
```

### Flow demonstrated

1. The Copier answers produce an Xcode project whose `Info.plist` expands
   `HotwireRootURL` from `$(WEB_ORIGIN)` and `WKAppBoundDomains` from
   `$(APP_BOUND_DOMAIN)`. `make.sh` derives the hostname from the origin, and
   the shell refuses to start if they disagree.
2. `./make.sh test_ios` builds the static app, serves it with COOP/COEP, opens a
   Cloudflare quick tunnel and starts the app with that origin.
3. `OnlineFlowTests` loads the web runtime, creates "Buy oat milk", asserts the
   visible runtime status (`Runtime: all available (SQLite 3.54.1 in OPFS)`,
   secure context, cross-origin isolation, service worker, Web Locks, OPFS), and
   exercises native About + back navigation.
4. The harness stops the tunnel and polls until the origin is unreachable.
5. `OfflineRelaunchTests` relaunches the app and asserts the saved task appears
   from the service-worker cache and OPFS — no native database, no bundled
   assets.

## Checks

Local results on a rendered project (`.render-check/generated`), macOS 26 with
Xcode 27.1 / iOS 27.1 simulator and a current `cloudflared`:

| Check | Command | Result |
|---|---|---|
| Template render + neutrality | `./make.sh test` (template repo) | pass |
| Formatting, ESLint, `tsc` (src/worker/tests/scripts) | `./make.sh lint` | pass |
| Integration tests (real services/SQLite + runtime/origin logic) | `./make.sh test` | **17/17 pass** |
| Static build | `./make.sh build` | pass |
| Chrome E2E, dev + static | `./make.sh test_e2e` | **5/5 + 5/5 pass** |
| iOS simulator build | `./make.sh build_ios` | `** BUILD SUCCEEDED **` |
| iOS online flow | `./make.sh test_ios` | **passed** (29.0 s) |
| iOS offline relaunch (origin verified unreachable) | `./make.sh test_ios` | **passed** (12.3 s) |
| Spec harness tests | `node --test _specs/checks.test.mjs _specs/run-loop.test.mjs` | **6/6 pass** |
| Full slice gate | `bash _specs/checks.sh` (bare shell) | pass end to end |

GitHub Actions run
[`40918012764`](https://github.com/Deploy-your-Startup/local-first-app-template/actions/runs/40918012764)
passed `generated-project` (render, lint, integration, build, Chrome E2E) on
`43b6dee`.

The gate re-resolves its native prerequisites on every run: it exports
`DEVELOPER_DIR` from an installed Xcode when `xcode-select` points at the
Command Line Tools, and re-executes under `nix shell nixpkgs#cloudflared` when
`cloudflared` is not on `PATH`. This fixed the first loop validation, which
failed only because the gate inherited a shell with neither tool. No assertion
or scenario was removed or skipped; the native section now fails early with
guidance when `xcodebuild -version` cannot run.

CI stays Linux and runs render, lint, integration, build and Chrome E2E only.
The simulator result above is local evidence, not CI evidence.

## Skips and gaps

- **Xcode MCP**: opening the generated project through Xcode MCP requires a
  human approval in the Xcode UI (`xcrun mcp-server approve` needs sudo). The
  request is recorded but unapproved, so that checklist item is unchecked;
  native evidence comes from `xcodebuild` and XCUITest.
- "Offline" is simulated by stopping the tunnel and verifying the origin is
  unreachable. `simctl` cannot disable the simulator's host network.
- Physical iOS devices, signing/App Store distribution and a real CDN are not
  verified. App-bound enforcement was exercised against a `trycloudflare.com`
  hostname.
- Chrome offline restart, storage quota/eviction UI and multi-tab messaging stay
  in later slices.

## How to validate

```sh
# template repository, on macOS with Xcode and either cloudflared or nix
./make.sh test
./make.sh check
(cd .render-check/generated && ./make.sh build_ios && ./make.sh test_ios)

# full slice gate: renders, runs Chrome E2E and the simulator flow, and
# resolves Xcode/cloudflared itself
bash _specs/checks.sh
```

The tunnel URL is transient, is written to the gitignored
`app/.local-ios/origin.json`, and is never committed.
