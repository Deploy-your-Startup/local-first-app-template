# Scratchpad — cross-run memory

Working rules live in [todo.md](todo.md). The plan is
[local-first-app-template-plan.md](local-first-app-template-plan.md). The slice 0
deliverable is [extraction-map.md](extraction-map.md). This file is short on
purpose: read it first, update it last.

## Current position

- Slice **0** is complete: investigation and owner decisions **A1–A9** resolved,
  template repository cloned, GitHub access confirmed.
- Slice **1** is implemented on template branch `slice-1-chrome-task-persistence`
  (tip `5a69456`, which adds the relocated `_specs/`) and is open for review as
  PR #1 against `main`:
  https://github.com/Deploy-your-Startup/local-first-app-template/pull/1.
  Not merged.
- Slice **2 (iOS)** is reimplemented from Slice 1 on branch
  `slice-2-ios-wkwebview`, stacked on `slice-1-chrome-task-persistence`, and is
  draft PR #3:
  https://github.com/Deploy-your-Startup/local-first-app-template/pull/3.
  It stays draft because the Xcode MCP item needs a human approval in Xcode.
  The rolled-back attempt and its closed PR #2 are historical only.
- Next slice after review: **3** — the native Rust greeting. Do not start it
  before Slice 2 is reviewed/merged.
- Existing template repository at `projects/tooling/local-first-app-template`:
  own Git root, approved SSH origin, `main` tracking `origin/main`, initial
  commit `5c7afb7`, existing MIT LICENSE preserved. `gh repo view` reports
  `MAINTAIN` and the API reports push/maintain, so branch and PR publication
  are possible. No fork or extra remote exists.
- Template code, commits and PRs belong in that repository, not the Factory.
- Repository registered as tooling in the owner's `projects.yaml` (Factory-side
  registry, not template data).

## Tooling prerequisites

- Template and browser checks: Node.js 24 (this machine runs 23.11 and warns
  about ESLint engine ranges; all checks still pass), npm, Copier ≥ 9.18.2,
  Chromium for Playwright.
- Slice 2 native checks: macOS with a full Xcode that has an iOS simulator
  runtime, plus `cloudflared`. `_specs/checks.sh` now resolves both itself:
  when `xcodebuild` does not work under the current `xcode-select`, it exports
  `DEVELOPER_DIR` from the first installed Xcode whose `xcodebuild -version`
  succeeds; when `cloudflared` is missing it re-executes under
  `nix shell nixpkgs#cloudflared` (guarded against recursion). No Xcode version
  or personal path is hardcoded, and nothing is skipped — without either tool
  the gate fails with an actionable message.
- `xcode-select` on this machine points at the Command Line Tools, which is why
  the gate must select a full Xcode. The generated project never assumes this;
  it documents `cloudflared` and Xcode as prerequisites.
- `gh` is not on `PATH`; it runs through `nix shell nixpkgs#gh -c gh …`.
- Xcode MCP is configured but requires a human approval in the Xcode UI
  (`xcrun mcp-server approve` needs sudo). It was not available in this
  non-interactive run; the Xcode MCP checklist item stays open.

## Stacked-branch state

- Template repository: `main` at `5c7afb7`.
  - `slice-1-chrome-task-persistence` → PR #1 to `main` (first implementation
    PR).
  - `slice-2-ios-wkwebview` → draft PR #3, stacked on
    `slice-1-chrome-task-persistence`.
  - Closed PR #2 (`slice-2-ios-offline-webview`) is historical; do not reuse it.
  - Do not merge or force-push.

## Decisions taken (do not re-litigate)

- Slice 0 is documentation plus checkable assertions; no product code changes.
- `_specs/checks.sh` asserts the documented traces against the real source and,
  from slice 1, renders and tests a generated project. From slice 2 it also
  runs the rendered project's native build and simulator flow. `CHECKS_FAST=1`
  runs only structural assertions for `_specs/checks.test.mjs`; it is not
  evidence for completing a slice.
- Owner identifiers are described, never copied. `checks.sh` fails on a private
  tailnet host or `/Users/<name>` path in these files.
- Chrome and iOS WKWebView initially. Shared TypeScript services own task logic
  and SQLite WASM/OPFS/Drizzle persistence on both, with no separate native DB.
- iOS loads from CDN/Vite; cached PWA-style offline reopening follows an initial
  online load. No bundled assets, offline first-launch requirement or hosting
  setup.
- Rust stays native-only permanently for browser-inaccessible capabilities.
  Slice 3 adds only a real web UI → Swift → UniFFI → Rust → UI greeting.
- One database-owning tab; other tabs show "App already open in another tab".
  Slice 1 already holds the exclusive Web Lock and fails fast; slice 6 owns the
  explicit user-facing state and its tests.
- WKWebView exposes service workers only with
  `limitsNavigationsToAppBoundDomains` and a matching `WKAppBoundDomains`
  hostname. Never widen the allowed domain; derive it from `WEB_ORIGIN`.

### Slice 1 template layout (keep unless a later slice proves it wrong)

- Copier uses `_subdirectory: template`, `_templates_suffix: ''` and the Factory
  delimiters `§§deploy_your_startup.<var>§§`; verified that binary assets render
  byte-identical. Answers: `project_name`, derived `app_title`.
- `template/app` holds the runnable application, its `tests/integration`
  (node --test over real `node:sqlite`) and `tests/e2e` (Playwright). The
  repository-root `tests/` holds template rendering checks only.
- Relative imports use explicit `.ts` extensions so Node.js can execute the real
  service and integration tests without a bundler. `scripts/web-origin.ts` is
  imported by both a Node test and the simulator harness.
- SQLite WASM/JS is vendored at `app/public/sqlite/3.54.1/` and loaded by URL, so
  dev and the static build serve the same pinned runtime.
- No Nix flake: the generated project needs Node 24 + npm, plus Xcode and
  `cloudflared` for the optional native checks.
- `./make.sh check` (template repo) renders into `.render-check/generated`
  (gitignored) and runs the generated project's lint, integration, build and
  Chrome E2E. Rendering uses `--vcs-ref HEAD`, so uncommitted template changes
  are not tested; `checks.sh` fails on a dirty template tree for that reason.
- `startup-template.yml` (the CLI capability manifest) is deliberately absent
  until slice 9 inspects the real `bootstrap` custom-template contract.

### Slice 2 additions (keep unless a later slice proves them wrong)

- Copier answers add `ios_display_name` (default `app_title`),
  `ios_bundle_identifier` (default `com.example.<project_name>`),
  `web_origin` (default `http://localhost:4173`) and `app_bound_domain` (derived
  from `web_origin`). Verified that a custom `web_origin` recomputes
  `app_bound_domain`; `render_test.sh` asserts it.
- `template/native/ios/` holds a committed Xcode project generated once with
  Ruby `xcodeproj`. Sources: UIKit scene lifecycle, Hotwire Native 1.3.1 through
  SPM (up-to-next-major), `AppDelegate` enabling app-bound navigation,
  `SceneDelegate` validating origin/domain, a Hotwire web view controller that
  adds a native "About" button, and a native About screen.
- `Info.plist` contains only `$(WEB_ORIGIN)` and `$(APP_BOUND_DOMAIN)`; the
  project defaults them to `http://localhost:4173` and `localhost`. `make.sh`
  derives the hostname for every build with `app/scripts/web-origin.ts`, which
  also rejects non-HTTPS origins except loopback and paths/queries.
- Native tests are split into `OnlineFlowTests` (load the tunnel origin, create
  "Buy oat milk", assert `Runtime: all available` + `SQLite 3.54.1 in OPFS`,
  exercise About + back) and `OfflineRelaunchTests` (after the harness stops the
  tunnel and verifies the origin unreachable, assert the task and runtime).
- `app/scripts/ios-simulator.mjs` serves `dist` with `vite preview`, opens a
  Cloudflare quick tunnel, parses the URL, boots the first available simulator,
  uninstalls the app, runs the online test, kills the tunnel, polls until the
  origin is unreachable, then runs the offline test. The transient origin is
  written to gitignored `app/.local-ios/origin.json`. `--serve` keeps it open
  for manual Xcode runs.
- Vite dev/preview set `allowedHosts: [".trycloudflare.com"]`; without it Vite
  rejects the tunnel Host header with 403 and the tunnel "never answers". This
  was the first real failure of the slice.
- Offline reopen needs a Workbox `NavigationRoute` to the precached
  `index.html` (production only; the dev worker is never offline-tested).
- `make.sh` exposes `build_ios`/`test_ios`; `check` runs them on macOS with
  Xcode and prints an explicit skip elsewhere. mise exposes `build:ios` and
  `test:ios`.
- The visible footer status line is built from real observations in the page and
  the database worker (`shared/runtime.ts` + a `database-diagnostics` message).
  Chrome asserts it via Playwright; the simulator asserts the same text.
- XCUITest cannot reach the host's loopback control server (connection refused
  from the simulator), which is why offline is a second xcodebuild invocation
  after the harness stops the tunnel. The app container survives the second
  install; verified by the passing offline test.

## Known gaps carried forward

1. The source application's browser SQLite/OPFS/Drizzle path is still **unwired**
   (`app/src/database.ts` is never imported there); the template fixes this by
   importing it from `src/main.ts`. `checks.sh` still asserts the source gap so
   the extraction map cannot silently drift.
2. The source has **no task UI**; the template's form, list and Stimulus
   controller are new code in slice 1.
3. iOS remote HTTPS loading is proven in the simulator: app-bound domains,
   secure context, service-worker control/caching, offline relaunch with the
   origin unreachable, worker routing and OPFS persistence. Physical devices
   are untested, and app-bound enforcement was exercised against a
   `trycloudflare.com` hostname, not a registrable CDN domain.
4. Rust has **no SQLite** and none is required. The greeting is separate from
   CRUD.
5. The source has **no LICENSE file**; only `rustsrc` declares MIT. The owner has
   selected MIT, the template remote already has it, and generated projects now
   carry `LICENSE` plus `app/THIRD-PARTY-NOTICES.md`.
6. Storage limits are documented in the generated README, but quota/eviction
   failures are not surfaced in the UI (slices 5–6).
7. `npm install` warns about ESLint engine ranges because this machine runs
   Node.js 23.11 while the project pins Node.js 24. ESLint and all checks still
   pass; CI uses Node.js 24.
8. CI is Linux only and runs render, lint, integration, build and browser
   checks. The iOS simulator check is local; CI cannot and does not prove it.
9. The Xcode MCP build/run/inspect item remains open because this session could
   not obtain the Xcode UI approval (the `approve` command needs sudo). Native
   evidence comes from `xcodebuild`/XCUITest through `./make.sh test_ios`.
10. "Offline" means the configured origin is unreachable (tunnel stopped and
    verified), not the simulator's host network being disabled.

## Run log

### 2026-10-29 — slice 0

- Traced the browser path (index.html → main.ts → sw.ts → Hono `/local` → DB
  worker → SQLite WASM 3.54.1 OPFS SAH pool → Drizzle) and the iOS path
  (AppDelegate → SceneDelegate remote root → InboxComponent bridge →
  InboxService → UniFFI → Rust IMAP), reading every file listed in the map.
- Read source guidance: root `AGENTS.md`, `app-src/AGENTS.md`,
  `.kiro/steering/*`, ADR 0005 and ADR 0100.
- Baseline checks on the **source** app (unchanged by this slice), run through
  the service wrapper:
  - `./make.sh lint` → pass (`cargo fmt --check`, `cargo clippy -D warnings`,
    prettier, eslint, `tsc` for app and worker)
  - `./make.sh test` → pass (cargo tests incl. the IMAP domain operation, plus
    14 Python binding/API/contract tests)
  - `./make.sh test_e2e` → pass (Playwright/Chromium 26/26, 49.5 s, GreenMail
    container via the running Docker daemon)
- Not run: the source iOS simulator suite. It needs Xcode plus a simulator and
  nothing in slice 0 touches native code; first required by slice 2.
- Factory-wide `node --test scripts/tests/*.test.mjs sprowi/*.integration.test.mjs`
  → fails in `sprowi/*.integration.test.mjs` because `yq` is missing on this
  machine. Pre-existing environment gap, not caused by this slice. Not a
  required check for slice 0.
- Blocker for the harness, not the slice: `gh` and `mise` are absent; `gh` runs
  through `nix shell nixpkgs#gh -c` and is authenticated as the owner.
- At that time no PR could be opened: the Factory checkout had no origin and
  owner decisions were unresolved. This historical blocker is superseded by the
  current position above; do not replay a Factory push into the new template.

### 2026-10-29 — owner clarifications and loop restart preparation

- Updated plan, checklist and extraction map for all owner decisions. Slices now
  run 1–10, with a dedicated Rust greeting at 3; no native persistence or bundles.
- Cloned and inspected the existing MIT repository and registered its remote.
- Updated checks to require resolved approvals and an independent repository,
  rather than insisting on obsolete approval blockers. Added regression scenarios.
- Current validation results are recorded in `_specs/pr/slice-0.md`; historical
  source baseline results above are not new template evidence.
- Current tools `gh`, `mise` and `yq` are on PATH, unlike the historical table.
- Restart checks, 6 loop/check regression scenarios, registry validation, shell
  syntax and `git diff --check` pass. Factory suite: 30 pass, 2 fail in
  `scripts/tests/update-templates.test.mjs` because Python cannot import
  `cli.startup` (`ModuleNotFoundError: No module named 'cli'`). No product E2E
  or simulator run: no application code changed and no generated app exists.
- No Factory workflow or lint task exists here; shell syntax is checked, but
  ShellCheck is unavailable. Application checks begin with implementation.

### 2026-10-29 — slice 1

- Resolved the slice 0 publishing blocker before implementing: `gh repo view`
  reported `viewerPermission: MAINTAIN` for
  `Deploy-your-Startup/local-first-app-template`, and
  `git push --dry-run origin main:refs/heads/<probe>` accepted a new ref. No fork
  and no extra remote were created.
- Built slice 1 in the template repository on `slice-1-chrome-task-persistence`
  (branched from `main` at `5c7afb7`). Copier baseline, parameterised answers,
  task form/list, Hono routes at `/local/tasks`, page relay, database worker,
  Drizzle service, OPFS SAH pool, service/mise commands, render checks and a CI
  workflow.
- Local results on the **rendered** project (`./make.sh check`):
  - lint → pass; integration 6/6; static build → pass; Chrome dev 4/4 and
    static 4/4.
- `_specs/checks.sh` extended; `_specs/checks.test.mjs` 3/3 pass.
- Published: branch pushed, ready PR #1 opened with `gh`. GitHub Actions run
  `40886397089` passed render, lint, 6/6 integration, build and 8/8 Chrome E2E.
- Factory-side files were intentionally left uncommitted in that run; the specs
  were later moved into the template repository (`5a69456`).

### 2026-10-29 — slice 2 (historical; rolled back; superseded)

**Superseded:** the owner rolled this slice back. It used a local HTTPS server
with a throwaway CA on `localhost:8443` instead of a Cloudflare Tunnel, and its
branch and PR were deleted/closed. It is not evidence for the current
implementation. The useful finding (service workers in WKWebView require
app-bound domains) was revalidated here.

### 2026-10-29 — slice 2 reimplemented from slice 1

- Re-verified publishing before implementing: `gh repo view` and the API both
  report maintain/push on the template repository; no fork or extra remote.
- Environment: Xcode 27.1 exists but `xcode-select` points at Command Line
  Tools, so every native command ran with `DEVELOPER_DIR` set. iOS 27.1 runtime
  and one booted simulator were available. `cloudflared` was used through
  `nix shell nixpkgs#cloudflared`.
- Implementation:
  - Web: visible runtime status (`shared/runtime.ts`, page + database-worker
    diagnostics), production `NavigationRoute` for offline document loads,
    `allowedHosts` for the tunnel, integration tests for runtime description and
    origin parsing, Chrome E2E scenario for the status line.
  - Native: generated Xcode project with Hotwire Native 1.3.1 SPM, UIKit scene
    shell, app-bound domain validation, native About screen, two XCUITest
    classes, `build_ios`/`test_ios`, tunnel harness, ADR 002, README/AGENTS.
  - Template: four new Copier answers, render assertions (including a custom
    `web_origin`), neutrality/tunnel/certificate checks, CI comment that native
    stays local.
- Iterations worth remembering:
  1. First tunnel attempt failed with "the tunnel origin never answered": Vite
     preview rejects foreign Host headers (403). Fixed with
     `allowedHosts: [".trycloudflare.com"]`.
  2. First native attempt failed to link (`undefined _main`) because the Ruby
     generator added file references without a Sources build phase.
  3. The single-test design using a loopback control endpoint failed
     (`ECONNREFUSED` from the simulator). Replaced with two xcodebuild
     invocations; the app container survives the second install.
- Passing results on the rendered project `demo-app`:
  - `./make.sh build` → pass
  - `./make.sh build_ios` → `** BUILD SUCCEEDED **`
  - `./make.sh test_ios` → `OnlineFlowTests` passed (29.0 s: create task,
    runtime all available, About + back), tunnel stopped and origin verified
    unreachable, `OfflineRelaunchTests` passed (12.3 s: saved task visible).
  - Integration 17/17 (6 task + 5 runtime + 6 origin); Chrome E2E 5/5 dev +
    5/5 static; template render assertions pass twice (default and custom
    origin).
  - `_specs/checks.sh` passed end to end (exit 0), including the native build
    and both simulator phases. `_specs/checks.test.mjs` + `run-loop.test.mjs`
    → 6/6.
  - Fixed during the gate run: example tunnel URLs in fixtures tripped the
    "no transient tunnel URL" check (now `.example.com`), and two structural
    greps targeted the rendered file instead of the templated one.
- Published: branch pushed, draft PR #3 opened against
  `slice-1-chrome-task-persistence`. GitHub Actions run `40916434815` (Ubuntu,
  Node.js 24) passed `generated-project` in 1m1s: render, lint, integration,
  build and Chrome E2E. The simulator result is local only.
- Xcode MCP: the workspace-open request is recorded but needs a human approval
  in Xcode (`xcrun mcp-server approve` requires sudo), so MCP build/run/inspect
  remains unchecked. CLI Xcode build and simulator tests are the recorded
  native evidence.

### 2026-10-29 — slice 2 validation gate: toolchain resolution

- The loop's bare `bash _specs/checks.sh` failed at the last slice 2 structural
  check with `FAIL cloudflared is required to serve the simulator origin over
  HTTPS`. The gate inherited a shell without `cloudflared`, and `xcode-select`
  on this machine points at the Command Line Tools, so `xcodebuild` would have
  failed next. No product code was wrong.
- Confirmed by running the same gate with the tools supplied externally
  (`DEVELOPER_DIR=… nix shell nixpkgs#cloudflared -c bash _specs/checks.sh`):
  exit 0. 17/17 integration, 5/5 dev + 5/5 static Chrome E2E, iOS
  `** BUILD SUCCEEDED **`, `OnlineFlowTests` passed, tunnel origin verified
  unreachable, `OfflineRelaunchTests` passed.
- Fix in `_specs/checks.sh` only (plus evidence docs): resolve the toolchain at
  startup. Re-exec under `nix shell nixpkgs#cloudflared` when `cloudflared` is
  absent and `nix` exists (`CHECKS_REEXEC` guards recursion); export
  `DEVELOPER_DIR` from the first `/Applications/Xcode*.app` whose
  `xcodebuild -version` succeeds when the current selection is Command Line
  Tools. The native section now also asserts `xcodebuild -version` runs, so a
  CLT-only host fails immediately with guidance.
- Nothing was mocked, skipped or weakened: the real tunnel, simulator,
  XCUITest, Chrome E2E and integration suites still run, and a missing tool
  still fails the gate.
- Re-ran the bare gate afterwards (`bash _specs/checks.sh`) to prove the fix.

