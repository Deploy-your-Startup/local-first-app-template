# Local-first template — vertical-slice TODO

Source plan: [local-first-app-template-plan.md](local-first-app-template-plan.md).
Evidence: [extraction-map.md](extraction-map.md).

Current baseline: **Slice 2 (iOS) is implemented on branch
`slice-2-ios-wkwebview`; Slice 1 is the last merged-predecessor slice.** Slice 2
was previously rolled back and has been reimplemented from Slice 1. Specs live in
this template repository.

## Confirmed scope

- Existing public MIT repository: `git@github.com:Deploy-your-Startup/local-first-app-template.git`, managed via `iljabauer`; local destination `projects/tooling/local-first-app-template/`. Inspect existing contents; do not create another remote.
- Minimal todo for now. TypeScript services own all task logic and SQLite WASM/OPFS persistence, retaining Drizzle, Hono and the database-worker boundary on both platforms. No separate iOS/native database or Rust task CRUD.
- Chrome and iOS WKWebView initially. Test each; do not claim Safari or Firefox support.
- iOS loads the web app from a CDN or Vite, with PWA-style offline use after initial online loading. No bundled web assets or offline first-launch requirement.
- Deliver a CDN-ready static build and local Vite development; hosting setup and deployment are deferred.
- Rust stays native-only permanently, for capabilities unavailable in the browser. A separate slice demonstrates only "hello from rust" through the real bridge.
- One tab owns database access; additional tabs show "App already open in another tab". No concurrent ownership or volatile fallback.
- No mail features, accounts, synchronization, analytics, marketing website or production provisioning. Do not promise backup or cross-platform data sharing.

## Working rules

- Build vertical tracer bullets, not separate frontend/database/native workstreams. Keep the working example in Copier from slice 1 and test freshly generated projects.
- Start each behavior change with executable GIVEN / WHEN / THEN integration or E2E scenarios. Tests specify behavior.
- Use real SQLite, worker routing, native bridges and generated UniFFI bindings. Do not mock our own code to make a slice pass.
- Expand service `make.sh`, root mise commands, guidance and CI with each slice. Preserve reproducible tooling without personal paths.
- After each slice, run its checks and all existing local lint and tests, including browser E2E and native checks where available. Record failures and skips; never mark an unverified platform complete.
- For each implementation slice (1–10), commit on a dedicated branch and create a stacked GitHub PR with `gh pr create`. The first targets the default branch; each subsequent PR targets its predecessor. Do not merge automatically.
- PRs link the plan, identify the slice and predecessor, describe the demonstrated flow and report checks, failures, skips and gaps. Blocked/incomplete slices remain draft with unchecked items.
- For work spanning repositories, maintain separate stacks and cross-link dependencies. Use authorized forks where needed; do not mix unrelated repositories into one PR. After merges, retarget and refresh without unauthorized force-pushes.
- Slice branch pushes and stacked PR creation are authorized by the owner. Public releases and infrastructure changes still require separate approval. Do not modify the source startup for this extraction.
- If the approved web storage/offline path fails in WKWebView, stop and seek an owner decision. Do not substitute native SQLite, bundled assets or online-only loading.

## 0. Establish the extraction boundary and approvals

Status: **complete.** Owner scope decisions are resolved, the existing repository is cloned and fetch/push access is verified. `gh repo view` now reports `MAINTAIN` (previously `READ`) and a dry-run push of a new ref succeeds, so upstream branch and PR publication are possible. Application behavior was unverified at this stage and is proven in slice 1.

- [x] Read the source application's AGENTS.md, steering files, relevant ADRs, commands, workflows and licenses.
- [x] Trace browser UI/service-worker/Hono/database-worker/Drizzle/SQLite paths and record broken links.
- [x] Trace the existing iOS/Swift/UniFFI/Rust path and identify gaps.
- [x] Confirm repository name, owner, MIT license, public visibility, existing remote and local destination (A1–A5, A9).
- [x] Confirm always-native-only Rust, TypeScript-owned persistence, remote/Vite content loading and PWA-style offline reopening (A6–A8).
- [x] Record reusable code, exclusions, licensing obligations and compatibility risks without distributing owner data.
- [x] Inspect and clone the existing template repository: independent Git root, approved origin, clean `main` tracking `origin/main`, existing MIT LICENSE. Fetch access verified; do not infer push/PR permissions from cloning.
- Implementation starts with slice 1 in the template repository. The Factory's local slice-0 branch is not part of that repository's PR stack.
- [x] Resolve the GitHub CLI's READ-only permission before implementation/publishing: `gh repo view` reports `MAINTAIN` and `git push --dry-run origin main:refs/heads/...` accepts a new ref. No fork or additional remote was created.

**Gate:** enough evidence to build the first thin path, not a general persistence framework. No remote creation is needed.

## 1. Generate a Chrome app that saves one task locally

Status: **implemented, pushed and open for review as PR #1 (`slice-1-chrome-task-persistence` → `main` in the template repository).** All checks pass locally against a freshly rendered project — lint, 6 integration tests, the static build, and 4 Chrome E2E scenarios run twice (Vite dev and `vite preview`) — and GitHub Actions passed the same steps on the PR. Native, offline and multi-tab behavior remain later slices and are reported as skips.

**Tracer:** Copier → Vite/Turbo/Stimulus UI → Hono/service worker → database worker → TypeScript service/Drizzle → SQLite WASM/OPFS → list → reload.

- [x] Establish a minimal Copier baseline in the existing repository and render a disposable project from a committed template version.
- [x] Parameterize the project name; include neutral examples and MIT/third-party notices, not source branding, answers, Vault data, hosts or history.
- [x] Add a task form and list; connect the database client and real create/list routes.
- [x] Persist through SQLite WASM/OPFS and Drizzle with an initial schema.
- [x] Expose setup/dev/build/format/lint/tests through service and mise commands.
- [x] Add real Chrome E2E for create → reload → saved task, plus invalid-title rejection that stores nothing.
- [x] Run generation and the flow through local checks and a CI entrypoint; use the static production build as well as development checks where relevant.

**Done:** a fresh generated project saves and reloads one task without an account or application backend.

## 2. Save and reopen one task in iOS WKWebView using the web runtime

Status: **implemented on `slice-2-ios-wkwebview` (stacked on
`slice-1-chrome-task-persistence`) and open for review as draft PR #3:**
https://github.com/Deploy-your-Startup/local-first-app-template/pull/3.
The PR stays draft because the Xcode MCP checklist item needs a human approval
in the Xcode UI. The generated
simulator flow loads the static build through a Cloudflare Tunnel, saves a task,
checks the WKWebView runtime status and native navigation, then stops the tunnel,
verifies the origin is unreachable and reopens the saved task from cached UI and
OPFS. Native test results are recorded in the scratchpad; CI remains Linux-only
and does not prove the simulator.

**Tracer:** generated Hotwire Native shell → remotely served web UI → same TypeScript/Hono/database-worker/SQLite WASM path → terminate → offline relaunch → saved task.

The slice gate resolves its own native toolchain: `_specs/checks.sh` selects an
installed Xcode when `xcode-select` points at the Command Line Tools and supplies
`cloudflared` when it is absent. `bash _specs/checks.sh` therefore runs in a bare
shell without hardcoded versions and without skipping a check.

- [x] Parameterize display name and bundle identifier; build for a simulator without personal signing identities or hardcoded Xcode paths.
- [x] For this local validation session, run `export DEVELOPER_DIR="/Applications/Xcode-27.1.0.app/Contents/Developer"` before invoking Xcode command-line tools. Keep this machine-specific selection out of generated template defaults.
- [x] Use Xcode MCP to build, run and inspect the generated iOS app in the simulator; record native test results rather than inferring success from browser checks.
- [x] Use a Cloudflare Tunnel to expose local Vite or the local static-build test server over HTTPS. Load the provided HTTPS tunnel URL in the iOS shell; do not provision production hosting or commit a transient tunnel URL as a template default.
- [x] Configure `WKAppBoundDomains` in `Info.plist` with the hostname parsed from the provided HTTPS tunnel URL (no scheme, port or path), and enable `WKWebViewConfiguration.limitsNavigationsToAppBoundDomains`. Keep the configured web origin and allowed hostname aligned when the tunnel URL changes; use the corresponding CDN hostname for CDN-style loading.
- [x] Prove secure context, service-worker control/caching, database workers, Web Locks and OPFS inside the actual WKWebView configuration.
- [x] Use the same TypeScript services and schema as Chrome. Do not add native persistence or assume the two platforms share database files.
- [x] Add simulator UI E2E: load online, create a task, terminate, disable networking, relaunch and observe the saved task from cached UI and durable web storage.
- [x] Exercise minimal native navigation/back behavior.
- [x] Document proven origin, caching and storage choices in an ADR; expose native build/simulator checks through existing commands.
- [x] Stop for an owner decision if this path fails. Record failures/skips rather than substituting a different architecture.

**Done:** cached offline reopening and durable task access work in WKWebView after initial online loading. No bundled assets or first-ever offline launch is required; a Chrome pass is not iOS evidence.

Revalidated from Slice 1; the archived historical Slice 2 draft and results are
not evidence for this implementation. The runtime status line, simulator UI
tests, tunnel harness and ADR 002 are new code in this slice.

## 3. Say "hello from rust" through the native bridge

**Tracer:** web UI action → Swift bridge → generated UniFFI bindings → Rust → Swift → web UI displays "hello from rust".

- [ ] Add the smallest neutral native Rust crate and greeting operation; generate Swift bindings at build time.
- [ ] Reuse explicit bridge events, request/response validation, correlation IDs and stable error reporting where appropriate.
- [ ] Add simulator E2E proving the real UI round trip, plus an observable bridge-error scenario.
- [ ] Handle unavailable native capability explicitly in Chrome; never claim Rust executed there.
- [ ] Expose Rust/binding/native checks and keep generated bindings/build artifacts out of template sources.
- [ ] Keep task logic and persistence entirely independent of the greeting and Rust.

**Done:** the real native bridge displays the Rust response; this proves plumbing only, not a native task service or database.

## 4. Complete and reopen tasks on both platforms

- [ ] Implement completion/reopening in shared TypeScript services and update the Hotwire UI.
- [ ] Add Chrome and simulator UI scenarios proving each state survives reload/relaunch.
- [ ] Verify the actual web persistence path in both runtimes, without routing task actions through Swift or Rust.

**Done:** completion and reopening are durable user actions on both platforms.

## 5. Edit and delete tasks on both platforms

- [ ] Add title editing through the shared web path; invalid edits preserve the saved title and show actionable validation.
- [ ] Add deletion with an explicit interaction preventing accidental destructive actions.
- [ ] Add Chrome and simulator scenarios for edits, invalid edits and deletion, including persistence after restart.
- [ ] Surface persistence failures without claiming success.

**Done:** the generated todo supports create/list/edit/complete/reopen/delete on both platforms.

## 6. Keep full task behavior offline and report storage failures honestly

- [ ] On Chrome and WKWebView, load online, disable networking, restart and exercise full task behavior against real SQLite storage.
- [ ] Test unsupported storage and initialization failures at real platform boundaries; no silent volatile fallback.
- [ ] Test real concurrent tabs and OPFS locking: one owner, explicit "App already open in another tab" in other tabs, no false success or concurrent writes.
- [ ] Test owner closure and subsequent database access without destructive resets.
- [ ] Document tested Chrome/iOS versions, storage eviction limitations and persistent-storage requirements. No backup/sync promises.

**Done:** cached offline use is demonstrated, and unavailable/contended storage cannot masquerade as a successful save.

## 7. Upgrade assets and schema without losing tasks

**Tracer:** old build with saved tasks → new cached assets/schema → same tasks visible through UI on Chrome and WKWebView.

- [ ] Add a small real schema migration with existing task records and completion states.
- [ ] Exercise service-worker activation/cache updates with an old app/tab present and define safe mixed-version handling.
- [ ] Exercise the shared TypeScript/web SQLite migration in Chrome and WKWebView; no native/Rust database migration.
- [ ] Assert tasks and completion states survive upgrades through the user interface.
- [ ] Show migration failure/recovery guidance without automatically resetting data.

**Done:** upgrade tests begin with old persisted data, not empty databases, and preserve observable behavior on both platforms.

## 8. Prove independent generation and safe Copier updates

- [ ] Generate two projects with distinct names, display names and bundle IDs; build and exercise task flows and the native greeting.
- [ ] Scan for unresolved placeholders, source branding, credentials, private hosts and machine settings.
- [ ] Supply concise root/service agent guidance, template-owned ADRs and a critical-flow-to-test map.
- [ ] Test real Copier updates between committed versions with application customizations and owner settings; verify preservation and conflict handling.
- [ ] Keep credentials/signing identities out of answers/defaults; confirm updated projects still pass Chrome and native user-flow checks.

**Done:** independent projects can be generated and updated safely, not just renamed demos.

## 9. Generate and run through a verified Factory entrypoint

- [ ] Inspect the actual CLI custom-template contract/capability manifest; do not assume fullstack/pitch paths support this project.
- [ ] Select and document the smallest working generation path. If CLI changes are needed, test them in their owning repository before claiming bootstrap compatibility.
- [ ] Test generation without cloud accounts, provisioning, production secrets or unexpected hosted application services.
- [ ] Register the approved existing remote in the owner's tooling registry if needed; never distribute the personal registry as template data.
- [ ] Run the documented command, start the web app/static build and shell, and verify task persistence plus native greeting.

**Done:** the documented entrypoint produces a runnable project without provisioning hosting. A built-in CLI menu entry is optional.

## 10. Qualify the release candidate

- [ ] Run template checks and all generated-project lint, integration, Chrome E2E, Rust and iOS simulator checks locally; record failures/skips.
- [ ] Verify CI renders projects and uses the same service contracts. Review workflow `run_e2e`; preserve required Dependabot E2E behavior.
- [ ] Review README, prerequisites, MIT/third-party notices, capabilities, tested versions and generation/update commands against evidence.
- [ ] Verify the CDN-ready static output and required serving headers without claiming an actual CDN deployment.
- [ ] Record platform/storage limitations and remaining gaps; do not claim untested compatibility, production readiness or App Store readiness.
- [ ] Obtain release publication approval; tag only the tested commit and document its exact source/version.

**Done:** a reproducible release candidate is ready for review. Signing, App Store distribution, hosting and production rollout remain separate work.
