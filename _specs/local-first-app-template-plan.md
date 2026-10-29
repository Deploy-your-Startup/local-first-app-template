# Local-first application template — implementation plan

## Goal

Extract a reusable Factory application template from the existing local-first
application, without copying mail functionality, owner data or production
configuration. Generate independent projects with TypeScript, Vite, Hono,
service workers, Hotwire, Hotwire Native for iOS and a native Rust core exposed
to Swift through UniFFI.

This is an implementation plan, not a separate behavioral specification.
Executable GIVEN / WHEN / THEN integration and E2E tests will be the source of
truth for generated application behavior.

## Agreed foundation

- TypeScript and Vite for the web application and asset build.
- Turbo and Stimulus for web navigation and interactions.
- Hono for local request routing in the service worker, not a hosted backend.
- SQLite WASM persisted in OPFS for browser data, retaining the existing Drizzle
  integration rather than replacing it with IndexedDB.
- Hotwire Native for the iOS shell and native navigation.
- Rust for native application functionality, with UniFFI-generated Swift bindings.
- Factory-compatible development commands, agent guidance and automated checks.
- **Owner confirmed initial platform scope:** Google Chrome and iOS WKWebView. Verify persistence, service-worker caching, offline reopening and updates on each; Safari and Firefox are not initially claimed as supported.
- **Owner confirmed multi-tab policy:** only one tab owns database access; other tabs show an explicit "App already open in another tab" state. Do not silently fall back to volatile storage or attempt concurrent database ownership.

UniFFI connects Swift to Rust; it does not connect browser TypeScript to Rust.
The web-to-native bridge is a separate boundary that must be demonstrated and
tested. Task persistence stays in the web runtime on both platforms. Chrome and
iOS WKWebView have separate origin-scoped stores; no shared database file or
automatic synchronization is promised.

## Confirmed initial scope

- **Owner confirmed for now:** use a minimal todo application to demonstrate creating, listing, editing, completing, reopening and deleting tasks. All task logic and persistence belong in TypeScript services; do not introduce artificial Rust involvement in task CRUD.
- Keep the marketing website, mail features, accounts, synchronization, analytics and production provisioning out of the first release.
- **Owner confirmed delivery scope:** provide a CDN-ready static build and local Vite development; defer actual hosting setup and deployment.
- Load iOS web content from a CDN, or Vite during local development. Do not bundle web assets or require offline first launch. Require PWA-style caching and offline use after initial online loading, following the reference project; verify this in the actual iOS WebView rather than assuming support.
- Rust is always native-only, reserved for capabilities unavailable in the browser (e.g. TCP connections). Implement application logic in TypeScript services; do not plan a browser WASM build of the Rust core.
- **Owner confirmed:** add a dedicated thin slice demonstrating web UI → Swift bridge → generated UniFFI bindings → Rust → web UI with a simple "hello from rust" response. This validates bridge plumbing only, not task logic or native persistence.
- No separate iOS/native SQLite persistence. Native capabilities communicate results back to the web app; TypeScript services own persistence into web SQLite. Prove storage compatibility in the chosen iOS WebView configuration.
- Use the existing public MIT repository
  `git@github.com:Deploy-your-Startup/local-first-app-template.git`, managed by
  `iljabauer`, at `projects/tooling/local-first-app-template/`. Inspect existing
  contents and verify access before implementation; do not create another remote.

These scope decisions are owner-approved. Implementation and platform support
remain unverified until the corresponding generated-project tests pass.

## Phase 1 — inspect and separate reusable architecture

1. Read application instructions, including its steering files, architecture
   decisions, service commands and workflows.
2. Map the actual service-worker, Hono, Hotwire, SQLite/OPFS, Swift and Rust paths.
   Identify any requested stack components not yet implemented in the source.
3. Trace browser requests through routing, persistence and UI updates. Trace an
   iOS interaction through the JavaScript/Swift bridge, UniFFI and Rust.
4. Record browser support, storage durability constraints, worker ownership,
   multi-tab locking, update behavior and required response headers.
5. Identify reusable code and tests versus mail-specific behavior, imported
   history, machine settings and production configuration.
6. Review source and dependency licenses before reusing or publishing code.

Deliverable: a reviewed extraction map and explicit compatibility gaps. Do not
copy the application's Git history into the template by default.

## Phase 2 — prove the browser and iOS execution paths

1. Build the smallest browser example using Hono, a service worker and the
   existing SQLite WASM/OPFS approach.
2. Demonstrate a local write, reload and offline read using real persistence.
3. Load the same web UI in Hotwire Native from a configurable HTTPS origin,
   using Vite in development and a local static-build server for CDN-like tests.
   Prove app-bound-domain configuration, secure context, service-worker control,
   database workers, Web Locks and SQLite WASM/OPFS in actual iOS WKWebView.
4. After an initial online load, create a task, terminate the app, disable
   networking and relaunch. Prove cached UI loading and durable task access
   through the same TypeScript/Hono/Drizzle path used by Chrome.
5. Stop and seek an owner decision if WKWebView cannot support that path; do not
   silently substitute native persistence, bundled assets or online-only loading.
6. In a separate slice, demonstrate web UI → Swift → generated UniFFI → Rust →
   web UI returning "hello from rust", including observable bridge failures.
   This is a plumbing demonstration, not a task service or database dependency.

Exit condition: both platforms can create and reopen local tasks offline after
an initial online load, without accounts or a hosted application backend. A
first-ever offline launch is not required; the Rust greeting is independent.

## Phase 3 — create the Copier template

Use the existing approved repository under
`projects/tooling/local-first-app-template/`, inspecting its contents before
cloning or editing. Reuse the existing templates' Copier conventions, service command
contract and test harness; do not inherit Django deployment assumptions merely
because the source startup originated from that template.

Suggested repository shape, subject to the extraction review:

```text
copier.yml
startup-template.yml
template/
  app/                 # Vite, TypeScript, Hotwire and local web runtime
  native/ios/          # Hotwire Native shell and Swift bridge
  native/core/         # Rust core and UniFFI binding configuration
  tests/               # Cross-boundary integration checks
  e2e_tests/           # Browser user-flow checks
  docs/                # Architecture, operations and testing guidance
  AGENTS.md
  mise.toml
  flake.nix
tests/                 # Template rendering and update checks
```

The final layout should preserve useful existing boundaries rather than force a
rewrite to match this illustration.

- Parameterize project name, display name, iOS bundle identifier and other
  required public identifiers.
- Keep credentials, signing identities and machine-specific Xcode paths out of
  answers and defaults. Document supported Xcode selection and local overrides.
- Generate fresh project answers; never copy the source startup's answers file,
  Vault content, domains, keys, operator information or deployment context.
- Supply concise service-local instructions and template-owned ADRs. Do not
  distribute project-specific import-history guidance as generic architecture.
- Protect owner-authored configuration on updates where appropriate. Verify
  preservation behavior with real Copier updates.
- Advertise only template capabilities actually supported and tested.

## Phase 4 — integrate with the Factory and CLI

1. Review the `startup bootstrap` custom-template contract. Its current fullstack
   and pitch paths may assume hosted services; accepting a template URL alone
   does not prove support for a local-first/native-only project.
2. Select the smallest supported generation path. If local-only generation needs
   CLI changes, scope and test that change explicitly rather than provisioning
   unwanted servers or adding fictitious deployment capabilities.
3. Register the actual template Git remote as tooling in the owner's registry.
   Do not copy the owner's registry into shared template content.
4. Document a verified generation command only after exercising it end to end.
   A built-in interactive menu entry is optional and separate from custom source
   support.

## Phase 5 — executable acceptance coverage

Implement real integration and E2E scenarios for:

- Fresh generation with two distinct project names and bundle identifiers, with
  no source branding, unresolved placeholders or private owner data.
- Task creation, editing, completion, reopening and deletion in Chrome and iOS
  WKWebView, through shared TypeScript services and web SQLite, persisted through
  reload/relaunch and offline restart after initial online loading.
- Service-worker installation, cached asset upgrades and SQLite schema migration
  preserving existing records on both Chrome and iOS WKWebView.
- Unsupported storage and initialization failures, with observable recovery
  guidance rather than silent data loss or volatile fallback.
- One database-owning tab; additional tabs show "App already open in another
  tab". Test real locking, owner closure and subsequent access.
- iOS cached offline startup and web SQLite persistence after initial online
  loading, across app termination and relaunch.
- A separate real UI-to-Swift-to-UniFFI-to-Rust "hello from rust" round trip,
  including failure propagation and browser handling when no native bridge exists.
- Native navigation and back behavior through Hotwire Native.
- Template updates preserving application customizations and owner settings.

Use isolated local fixtures, real SQLite and real public interfaces. Run native
checks on a supported macOS/Xcode simulator environment; record unavailable
platform checks as skips, not passes.

## Phase 6 — validation and release

- Expose setup, development, build, format, lint and test through service
  `make.sh` wrappers and root mise tasks. Formatting may write; lint must not.
- Retain pinned reproducible tooling where appropriate and document Nix, browser
  and Xcode prerequisites without personal machine paths.
- Run template checks and all generated-project lint, integration, browser E2E,
  Rust and iOS checks locally before claiming implementation complete.
- Review workflow `run_e2e` behavior; keep Dependabot E2E enabled in CI according
  to the owning repository's policy.
- Record executed checks, failures, skips and remaining compatibility gaps.
- Publish only with owner approval, then tag a tested release and document the
  exact source/version used to generate projects.
- Treat app signing, App Store distribution, web hosting and production rollout
  as separate work requiring their own approval and verification.
