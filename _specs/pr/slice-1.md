# Slice 1 — a generated Chrome app that saves one task locally

Source plan: [`_specs/local-first-app-template-plan.md`](../local-first-app-template-plan.md) (now maintained in this template repository).
Checklist: slice 1 in the workspace TODO (`_specs/todo.md`).

**Slice:** 1 of 10 — *Generate a Chrome app that saves one task locally*.
**Predecessor:** none. This is the first implementation PR and targets `main`.
**Template:** first Copier baseline; nothing is published or deployed.

## What changed

A Copier template that renders a runnable local-first task application.

```
copier.yml                  project_name / app_title answers, Factory delimiters
startup-template.yml        (absent on purpose; CLI contract is slice 9)
template/app                Vite + TypeScript application
  src/main.ts               registers the service worker, wires the frame
  src/database.ts           starts the DB worker and relays SW messages
  src/controllers/          Stimulus controller for the task form
  worker/sw.ts              Hono router mounted at /local
  worker/database.ts        owns SQLite WASM in OPFS (SAH pool) via Drizzle
  worker/services/tasks.ts  task service (validation + persistence)
  shared/tasks.ts           single source of truth for schema and messages
  tests/integration/        node --test over real SQLite (node:sqlite)
  tests/e2e/                Playwright, dev server and static build
  public/sqlite/3.54.1/     pinned SQLite WASM/JS + upstream notice
template/make.sh, mise.toml setup_local/run_dev/format/lint/build/test/test_e2e
template/docs/architecture/001-local-web-runtime.md
tests/                      template rendering + generated-project checks
.github/workflows/          render → lint → test → build → Chrome E2E
```

### Runtime flow (the vertical tracer)

`index.html` → `src/main.ts` → service worker (Hono `/local/tasks`) → page
message relay → database worker → Drizzle → SQLite WASM/OPFS → Turbo frame →
reload.

Notable decisions, all recorded in the generated project's ADR:

- The service worker is the HTTP surface only; a dedicated worker owns SQLite
  for the tab's lifetime behind an exclusive Web Lock.
- The initial schema is declared once in `shared/tasks.ts` and executed by both
  the database worker and the integration tests.
- Title validation lives in the service, so an invalid title is rejected before
  it can be stored.
- SQLite WASM/JS is served from `public/sqlite/3.54.1/` so the dev server and the
  static build load the same pinned runtime; the worker verifies the version.
- Dev and preview servers send `Cross-Origin-Opener-Policy` and
  `Cross-Origin-Embedder-Policy`, because OPFS requires a cross-origin isolated
  context.

## Tests and results

All results below are from `_specs/checks.sh`, which renders a disposable project
from the committed revision and runs that project's own checks.

| Check | Command | Result |
|---|---|---|
| Template render + neutrality assertions | `./make.sh test` (template repo) | pass |
| Formatting, ESLint 10, `tsc` (src, worker, tests) | `./make.sh lint` | pass |
| Integration (real service, real SQLite) | `./make.sh test` | **6/6 pass** |
| Static production build | `./make.sh build` | pass |
| Chrome E2E against Vite dev | `./make.sh test_e2e` (dev) | **4/4 pass** |
| Chrome E2E against `vite preview` | `./make.sh test_e2e` (static) | **4/4 pass** |

Integration scenarios: create + list with the stored row asserted in SQLite;
whitespace normalisation; newest-first ordering; empty title rejected and
nothing stored; over-limit title rejected and nothing stored; title at the limit
accepted.

E2E scenarios: create → reload → task still listed; two tasks stay newest-first
after reload; whitespace-only title shows "Enter a task title." and nothing is
stored after reload; the page is cross-origin isolated and controlled by its
service worker.

Render assertions: required files exist, the SQLite binaries are byte-identical,
no unresolved `§§` placeholders, no source branding, private hosts or personal
machine paths, `project_name`/`app_title` are substituted, and the generated
`package.json` declares the service scripts.

### Skips (recorded, not passed)

- **Native/iOS:** no native shell exists yet; slice 2 creates it and must prove
  WKWebView storage, caching and offline reopening itself.
- **Rust bridge:** the "hello from rust" round trip is slice 3.
- **Offline restart, multi-tab "already open in another tab" state:** slices 2
  and 6. Slice 1 already holds the exclusive database lock and fails fast, but
  the explicit user-facing state and its tests are not claimed here.
- **Safari/Firefox:** not claimed; Chrome is the only tested browser.

### Environment notes

- Local machine runs Node.js 23.11 (the project pins Node.js 24 in `mise.toml`),
  so `npm install` warns about ESLint's engine range. All checks still pass; CI
  uses Node.js 24.
- CI (`.github/workflows/template-check.yml`) runs the same steps on
  `ubuntu-latest`; this PR is its first execution.

## How to validate

```sh
git switch slice-1-chrome-task-persistence
cd projects/tooling/local-first-app-template   # in the Factory workspace
./make.sh lint
./make.sh test    # render a disposable project and assert its contents
./make.sh check   # render, install, lint, test, build, Chrome E2E (dev + static)
```

Or drive the app by hand:

```sh
copier copy --vcs-ref HEAD --data project_name=demo . /tmp/demo
cd /tmp/demo && ./make.sh setup_local && ./make.sh run_dev
# http://127.0.0.1:5173 — add a task, reload, the task is still there
```

To inspect the static build, run `./make.sh build` and `npm run preview` inside
`app/`.

## Not in this slice

Accounts, synchronization, hosting/CDN deployment, iOS, native Rust bridge,
service-worker caching guarantees, task editing/completion/deletion, and the
Factory CLI capability manifest. No production or release claims are made.
