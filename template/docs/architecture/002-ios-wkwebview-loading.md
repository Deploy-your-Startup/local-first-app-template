# Architecture decision 002: iOS loads the same web runtime remotely

## Status

Accepted for the iOS slice (one task saved in the simulator, then reopened with
the origin unreachable). Validated on the iOS Simulator only.

## Context

The application must run as a native iOS shell without a second database and
without bundling web assets. The web runtime already owns task logic, the Hono
service worker, the database worker and SQLite WASM in OPFS (ADR 001). The shell
may load that runtime from a CDN in production or from a local HTTPS server
during development; hosting and deployment are out of scope.

WKWebView restricts some web platform features. In particular, service workers
are exposed only when navigation is limited to app-bound domains. Getting this
wrong produces a page that claims service workers are unsupported, with no
useful error.

## Decision

The Hotwire Native shell loads a single configurable HTTPS origin:

- `WEB_ORIGIN` (a Copier answer with a local default) is expanded into
  `HotwireRootURL` in `Info.plist`.
- `APP_BOUND_DOMAIN` is expanded into the single `WKAppBoundDomains` entry. It
  is the hostname of `WEB_ORIGIN`: no scheme, port or path.
- `Hotwire.config.makeCustomWebView` enables
  `WKWebViewConfiguration.limitsNavigationsToAppBoundDomains`.
- `SceneDelegate` compares the origin host with the first allowed domain and
  shows a configuration error instead of silently loading nothing.
- `make.sh` derives the hostname from `WEB_ORIGIN` for every build, so a changed
  CDN or tunnel URL cannot leave the two values out of step. The generated
  project's `scripts/web-origin.mjs` owns that rule and is covered by tests.

The shell adds no persistence: the web app stores tasks in WKWebView's OPFS.
Native code owns only navigation (the root screen and a native "About" screen).
There is no bundled asset and no bundled web build; the first launch must be
online.

Offline reopening after that first online load relies on the service worker:

- The static build is precached (`vite-plugin-pwa`, inject-manifest strategy).
- A `NavigationRoute` answers document requests from the precached
  `index.html`, so a relaunch works when the origin cannot be reached.
- `/local/` requests are answered by the Hono router in the worker; `/sqlite/`
  is precached as an asset.
- The page shows a runtime status line built from what the page and database
  worker can actually observe (secure context, cross-origin isolation, service
  worker control, Web Locks, OPFS, SQLite version). Both the browser and the
  simulator assert that line instead of assuming support.

## Local verification

`./make.sh test_ios` runs `scripts/ios-simulator.mjs`, which:

1. serves the static build with COOP/COEP headers,
2. exposes it through a Cloudflare quick tunnel and requires the tunnel
   hostname for `WKAppBoundDomains`,
3. runs `OnlineFlowTests` (load, create task, runtime status, native
   navigation),
4. stops the tunnel, confirms the origin is unreachable, and runs
   `OfflineRelaunchTests` (the saved task must reappear from cached UI and OPFS).

The tunnel URL is transient and only written to the gitignored
`app/.local-ios/`. It is never a template default.

## Consequences

- Chrome and WKWebView share the TypeScript services, schema and request path,
  but each has its own origin-scoped storage. Nothing is synchronized.
- The simulated offline check makes the origin unreachable rather than turning
  off the simulator's host network; the network state is verified by the
  harness, not assumed.
- App-bound-domain enforcement is exercised against a Cloudflare tunnel
  hostname. Physical devices, a real CDN and App Store distribution remain
  unverified.
- Because app-bound domains are restrictive, every subresource - including the
  SQLite WASM runtime - must be served from the same origin.
- Storage eviction, quota failures and multi-tab handling are not yet addressed
  in the UI (later slices).
