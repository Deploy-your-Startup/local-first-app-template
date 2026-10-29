# Slice 0 — Extraction boundary and owner decisions

Source plan: [`_specs/local-first-app-template-plan.md`](../local-first-app-template-plan.md)
Task list: [`_specs/todo.md`](../todo.md)

## Status and repository boundary

This is the Factory's local investigation record, not an opened template PR.
The Factory branch `slice-0-extraction-boundary` has no origin. Do not push its
history into the template or use it as the template stack's predecessor.

Owner decisions A1–A9 are resolved. The existing template repository is cloned at
`projects/tooling/local-first-app-template`, has the approved SSH origin, and is
on clean `main` tracking `origin/main` (initial commit `5c7afb7`). It contains an
MIT LICENSE. Fetch access is verified. GitHub CLI viewerPermission is READ,
blocking upstream branch publication for that identity. Resolve access before
implementation/publishing; no SSH push has been attempted.
The first implementation PR (slice 1) targets that repository's `main`.

## Confirmed scope

- Minimal todo; TypeScript services own all task logic and web SQLite persistence
  on Chrome and iOS WKWebView. No native/Rust database or Rust task CRUD.
- Hotwire Native loads the web app from CDN/Vite. Prove cached PWA-style offline
  use after initial online loading; no bundled assets or offline first launch.
- Rust remains native-only permanently. Slice 3 demonstrates a real
  web UI → Swift → generated UniFFI → Rust → UI "hello from rust" round trip.
- One database-owning tab; other tabs show an explicit already-open message.
- CDN-ready static build only; hosting and deployment are deferred.

## Investigation findings

- The source database worker/OPFS/Drizzle code is not connected to the page.
  Slice 1 must wire it and add a task form/list, not just copy the source.
- The source iOS shell already loads remote content, but cached offline relaunch
  and durable web SQLite in its WKWebView remain unproven. Slice 2 is the gate.
- The source Rust crate is mail-specific. Reuse bridge/build patterns, not IMAP,
  credentials or product behavior. No native SQLite implementation is needed.
- The source has no top-level LICENSE; the owner selected MIT for the template.
  Preserve the existing template license and applicable third-party notices.

## Restart validation

Run from the Factory root:

```bash
bash _specs/checks.sh
node --test _specs/checks.test.mjs _specs/run-loop.test.mjs
bash scripts/registry.sh check
```

Current results:

- `bash _specs/checks.sh`: pass (source traces, approvals, repository and harness).
- Loop/check regression tests: 6/6 pass, including rejection of stale approvals
  and a missing independent template repository.
- Registry check: pass; approved template remote registered.
- Shell syntax (`bash -n`) and `git diff --check`: pass.
- Factory tests: 30 pass, 2 fail in `scripts/tests/update-templates.test.mjs`:
  Python cannot import `cli.startup` (`ModuleNotFoundError: No module named 'cli'`).
  These are outside the loop changes; they remain unresolved.
- No root lint task or workflow exists; ShellCheck is not on PATH.
- No generated application/browser/simulator checks run: no app exists yet.

These results validate restart documentation and the harness, not application
behavior or permission to publish upstream. No real agent loop was launched.

## Historical evidence — initial slice-0 run only

- Source service lint and tests passed, including 14 Python binding/API tests.
- Source Playwright/Chromium E2E passed 26/26 using GreenMail.
- Source simulator checks were not run; no native code changed in slice 0.
- Factory tests previously failed because `yq` was unavailable. Recheck the
  current environment rather than treating that observation as permanent.

No generated template application exists yet. Rendering, app lint/integration,
Chrome user-flow E2E and simulator checks are deferred to their implementation
slices, not counted as passes. Release publication still requires approval.
