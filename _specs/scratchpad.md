# Scratchpad — cross-run memory

Working rules live in [todo.md](todo.md). The plan is
[local-first-app-template-plan.md](local-first-app-template-plan.md). The slice 0
deliverable is [extraction-map.md](extraction-map.md). This file is short on
purpose: read it first, update it last.

## Current position

- Slice **0** is complete: investigation and owner decisions **A1–A9** resolved,
  template repository cloned, GitHub access confirmed.
- Slice **1** is implemented on template branch `slice-1-chrome-task-persistence`
  (tip `f075d04`) and is open for review as PR #1 against `main`:
  https://github.com/Deploy-your-Startup/local-first-app-template/pull/1.
  Local checks and the PR's GitHub Actions run both pass. Not merged.
- Slice **2** was rolled back. Its previous branch, PR draft and results are
  historical only; remote PR state has not been reverified.
- Next slice: **2** — save and reopen one task in iOS WKWebView. Start from
  Slice 1, not the rolled-back iOS implementation. Do not advance to Slice 3.
- Existing template repository at `projects/tooling/local-first-app-template`:
  own Git root, approved SSH origin, `main` tracking `origin/main`, initial
  commit `5c7afb7`, existing MIT LICENSE preserved. `gh repo view` reports
  `MAINTAIN`; push and PR creation for slice 2 succeeded. No fork or extra
  remote exists.
- Template code, commits and PRs belong in that repository, not the Factory.
- Repository registered as tooling in the owner's `projects.yaml` (Factory-side
  registry, not template data).

## Tooling prerequisites

Use the repository's pinned tooling and recheck availability locally. Slice 1
needs Node.js, Copier and Chromium for browser checks. Slice 2 will additionally
need full Xcode and an iOS simulator runtime; no native tooling is required by
the current Slice 1 checks. Machine-specific installation and selection settings
are not template data.

## Stacked-branch state

- Factory investigation branch: `slice-0-extraction-boundary`, local only; this
  parent checkout has no origin. No Factory PR is open. Its historical PR body
  remains in `_specs/pr/slice-0.md`; do not push Factory history to the template.
- Template repository: `main` at `5c7afb7`.
  - `slice-1-chrome-task-persistence` → PR #1 to `main` (first slice, so the PR
    base is the default branch).
   - Previous `slice-2-ios-offline-webview` work was rolled back; do not use it
     as the current predecessor. Reimplement Slice 2 from Slice 1.
   - Do not merge or force-push.

## Decisions taken (do not re-litigate)

- Slice 0 is documentation plus checkable assertions; no product code changes.
- `_specs/checks.sh` asserts the documented traces against the real source and,
  from slice 1, renders and tests a generated project. Extend it per slice;
  never replace with a placeholder.
- Owner identifiers are described, never copied. `checks.sh` fails on a private
  tailnet host or `/Users/<name>` path in these files.
- Chrome and iOS WKWebView initially. Shared TypeScript services own task logic
  and SQLite WASM/OPFS/Drizzle persistence on both, with no separate native DB.
- iOS loads from CDN/Vite; cached PWA-style offline reopening follows an initial
  online load. No bundled assets, offline first-launch requirement or hosting setup.
- Rust stays native-only permanently for browser-inaccessible capabilities.
  Slice 3 adds only a real web UI → Swift → UniFFI → Rust → UI greeting.
- One database-owning tab; other tabs show "App already open in another tab".
  Slice 1 already holds the exclusive Web Lock and fails fast; slice 6 owns the
  explicit user-facing state and its tests.
- The historical iOS attempt used app-bound domains for service workers.
  Revalidate that configuration in Slice 2; no iOS shell exists in the current
  baseline. Do not silently widen allowed domains.
- Stop for an owner decision if WKWebView cannot support the approved path;
  do not substitute native storage, bundled assets or volatile fallback. The
  approved path did work, so no decision is pending.

### Slice 1 template layout (keep unless a later slice proves it wrong)

- Copier uses `_subdirectory: template`, `_templates_suffix: ''` and the Factory
  delimiters `§§deploy_your_startup.<var>§§`; verified that binary assets render
  byte-identical. Answers: `project_name` and a derived `app_title`.
- `template/app` holds the runnable application, its `tests/integration`
  (node --test over real `node:sqlite`) and `tests/e2e` (Playwright). The
  repository-root `tests/` holds template rendering checks only.
- Relative imports use explicit `.ts` extensions so Node.js can execute the real
  service and integration tests without a bundler.
- SQLite WASM/JS is vendored at `app/public/sqlite/3.54.1/` and loaded by URL, so
  dev and the static build serve the same pinned runtime.
- No Nix flake yet: the generated project needs only Node 24 + npm. Do not add
  `path:..` factory inputs to a generated project.
- `./make.sh check` (template repo) renders into `.render-check/generated`
  (gitignored) and runs the generated project's own checks. Rendering uses
  `--vcs-ref HEAD`, so uncommitted template changes are not tested; `checks.sh`
  fails on a dirty template tree for that reason.
- `startup-template.yml` (the CLI capability manifest) is deliberately absent
  until slice 9 inspects the real `startup bootstrap` custom-template contract.

### Slice 2 additions (keep unless a later slice proves them wrong)

- Copier answers now include `ios_bundle_identifier` (default
  `com.example.<project_name>`) and `web_origin` (default
  `https://localhost:8443`), rendered into `native/ios/LocalFirstApp/Info.plist`
  and the UI test.
- `template/native/ios/` is a committed Xcode project generated once with Ruby
  `xcodeproj`; it references Hotwire Native 1.3.1 through SPM. The project file is
  checked in and no generator is required at build time.
- The shell uses the UIKit scene lifecycle. `AppDelegate` only returns the scene
  configuration; `SceneDelegate` creates the Hotwire `Navigator`, configures
  app-bound domains, adds the native "About" button and owns the window.
- `limitsNavigationsToAppBoundDomains` is **required** for service workers in
  WKWebView; with it off the page reports "This browser does not support service
  workers." Keep `WKAppBoundDomains` in sync with the origin.
- `app/scripts/serve-static-https.mjs` serves `dist` with COOP/COEP and
  `Service-Worker-Allowed: /`; `/__control/offline` makes the origin unreachable
  for the relaunch check. `make-dev-cert.sh` creates a throwaway CA/server cert
  in `app/.local-https/` (gitignored). Never commit certificates.
- `make.sh build_ios` / `test_ios` are the native commands; `check` includes them.
  The scripts select the first available iPhone simulator, install the CA with
  `simctl keychain`, and fail if a stale server already listens on 8443.
- The simulator UI test asserts `Runtime: all available` on the About page, so
  isolation, service worker, Web Locks and OPFS are proven in WKWebView.
- The "offline" check makes the origin unreachable; `simctl` cannot switch off
  the simulator's host network. Record this limitation rather than claiming
  airplane-mode coverage.

## Known gaps carried forward

1. The source application's browser SQLite/OPFS/Drizzle path is still **unwired**
   (`app/src/database.ts` is never imported there); the template fixes this by
   importing it from `src/main.ts`. `checks.sh` still asserts the source gap so
   the extraction map cannot silently drift.
2. The source has **no task UI**; the template's form, list and Stimulus
   controller are new code in slice 1.
3. iOS remote HTTPS loading is now proven in the simulator: service-worker
   caching, offline relaunch (origin unreachable), worker routing and OPFS
   persistence. Physical devices are still untested, and app-bound enforcement is
   only exercised against `localhost`, not a registrable CDN domain.
4. Rust has **no SQLite** and none is required. The greeting is separate from CRUD.
5. The source has **no LICENSE file**; only `rustsrc` declares MIT. The owner has
   selected MIT, the template remote already has it, and generated projects now
   carry `LICENSE` plus `app/THIRD-PARTY-NOTICES.md`.
6. Slice 2 documents storage limits in the generated README and proves offline
   relaunch, but does not yet surface storage-quota or eviction problems in the
   UI (slices 5–6).
7. `npm install` warns about ESLint engine ranges because this machine runs
   Node.js 23.11 while the project pins Node.js 24. ESLint and all checks still
   pass; CI uses Node.js 24.
8. CI is Linux only and runs the render, lint, integration, build and browser
   checks. The iOS simulator check is local; the PR must not claim CI proved it.

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
  now reports `viewerPermission: MAINTAIN` (was READ) for
  `Deploy-your-Startup/local-first-app-template`, and
  `git push --dry-run origin main:refs/heads/<probe>` accepted a new ref. No fork
  and no extra remote were created. `gh` is still not on PATH in this shell; it
  runs through `nix shell nixpkgs#gh -c gh …`.
- Built slice 1 in the template repository on `slice-1-chrome-task-persistence`
  (branched from `main` at `5c7afb7`). Copier baseline, parameterised answers,
  task form/list, Hono routes at `/local/tasks`, page relay, database worker,
  Drizzle service, OPFS SAH pool, service/mise commands, render checks and a CI
  workflow.
- Local results on the **rendered** project (`./make.sh check`, which renders
  from `HEAD` into `.render-check/generated`):
  - `./make.sh lint` → pass (prettier, ESLint 10, `tsc` for src, worker and tests)
  - `./make.sh test` → pass, 6/6 integration tests over real `node:sqlite`
  - `./make.sh build` → pass (static build, SQLite assets copied to `dist/sqlite/`)
  - `./make.sh test_e2e` → pass, 4/4 Chrome dev + 4/4 Chrome static
- `_specs/checks.sh` extended: slice 0 assertions retained; slice 1 adds template
  structure, a clean-tree guard, Copier answer/exclude assertions, CI-step
  assertions, render assertions and the full generated-project check. Full run
  passes end to end.
- `_specs/checks.test.mjs` → 3/3 pass.
- Skips (recorded, not passed): native/iOS (slice 2), Rust bridge (slice 3),
  offline restart and multi-tab state (slices 2, 6), Safari/Firefox.
- Observation: `npm install` warns about ESLint's Node engine range because this
  machine runs Node 23.11 while the project pins Node 24; all checks pass anyway.
- Published and verified: branch pushed (`git push -u origin
  slice-1-chrome-task-persistence`), draft PR #1 opened with `gh`, then marked
  ready for review after CI passed. PR body: `_specs/pr/slice-1.md`.
- GitHub Actions run `40886397089` (Ubuntu, Node.js 24) passed every step:
  render assertions, generated-project lint, 6/6 integration, static build,
  4/4 Chrome dev E2E and 4/4 Chrome static E2E. No merge, no force-push.
- Factory-side files updated but intentionally left uncommitted, like previous
  slices: `_specs/checks.sh`, `_specs/todo.md`, `_specs/scratchpad.md`,
  `_specs/pr/slice-1.md`. Template code is committed only in its own repository.

### 2026-10-29 — slice 2 (historical; rolled back)

**Superseded:** the owner rolled this slice back. The following records the
previous attempt, not current capabilities or validation.

- Re-verified publishing before implementing: `gh repo view` still reports
  `viewerPermission: MAINTAIN`; `git push --dry-run` accepted the new branch. No
  fork or extra remote. `gh` still runs via `nix shell nixpkgs#gh -c gh …`.
- Environment: Xcode 27.1 at `/Applications/Xcode-27.1.0.app` but `xcode-select`
  points at Command Line Tools; all native commands ran with `DEVELOPER_DIR`.
  iOS 27.1 runtime and a booted iPhone simulator were available.
- Built slice 2 on `slice-2-ios-offline-webview` from slice 1's tip `f075d04`.
  Added the render answers, HTTPS static server and throwaway CA, About page
  runtime diagnostic, Hotwire Native UIKit shell with scenes, simulator UI test,
  iOS commands, ADR 002 and docs.
- Key finding: WKWebView exposes service workers **only** when
  `limitsNavigationsToAppBoundDomains` is on. With it off, the page renders "This
  browser does not support service workers." App-bound domains with `localhost`
  work, so the flag is on by default.
- Generated project (`./make.sh check` from committed `7d7c76e`):
  - lint → pass; integration 6/6; build → pass
  - Chrome dev 4/4 (offline test skipped in dev by design), static 6/6, HTTPS
    static 6/6
  - `build_ios` → `** BUILD SUCCEEDED **`
  - `test_ios` → `** TEST SUCCEEDED **`, 1/1 XCUITest in 27.9 s
- `_specs/checks.sh` extended with slice 2 structure, app-bound/domain and
  runtime-diagnostic assertions, native script syntax, leak checks and Xcode
  detection; full run passes.
- `node --test _specs/run-loop.test.mjs _specs/checks.test.mjs` → 6/6 pass.
- Published: branch pushed, ready PR #2 opened with `gh` targeting
  `slice-1-chrome-task-persistence`. PR body: `_specs/pr/slice-2.md`.
- GitHub Actions run `40892667531` (Ubuntu, Node.js 24) passed every step:
  render assertions, generated-project lint, 6/6 integration, static build,
  4/4 dev + 6/6 static + 6/6 HTTPS Chrome E2E. Native checks stay local.
- Skips (recorded): physical iOS device, Safari/Firefox, CDN hosting, Rust bridge
  (slice 3), multi-tab UI state (slice 6). Offline is simulated by making the app
  origin unreachable, not by disabling the simulator's host network.
- Factory-side files updated but intentionally left uncommitted, as before:
  `_specs/checks.sh`, `_specs/todo.md`, `_specs/scratchpad.md`,
  `_specs/pr/slice-2.md`.

### 2026-10-29 — current baseline after rollback and spec relocation

- Specs now live in the template repository's `_specs/`, not the Factory root.
- Last completed slice: **Slice 1**, branch `slice-1-chrome-task-persistence`,
  commit `f075d04`. Next incomplete slice: **Slice 2 (iOS)**.
- Slice 2's checklist is reset. Its old PR draft and evidence are historical;
  they do not establish support in the current checkout. No remote PR state was
  checked or changed during this correction.
- Active checks must require only Slice 1: render, lint, integration, build,
  Chrome dev and static E2E. iOS, HTTPS origin, offline reopening and Rust remain
  future work. Do not advance to Slice 3 based on the previous Slice 2 attempt.
- Validation after correction: template lint and shell syntax pass;
  `./make.sh check` passes rendering, generated lint, 6 integration tests,
  build and 4 dev + 4 static Chrome E2E. Spec regression tests: 5/6 pass;
  the remaining check stops at the clean-tree guard because `_specs/` is
  uncommitted. No iOS checks run (rolled back). Node 23 engine warnings remain.
