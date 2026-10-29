# Architecture decision 002: iOS WKWebView runtime

## Status

Accepted for the second vertical slice: save and reopen one task in the iOS
simulator, including an offline relaunch after the first online load.

## Context

The iOS shell must load the same web runtime as Chrome from a remote origin. It
may not bundle web assets, add a native database, or keep working only online.
Hosting is not provisioned yet, so the checks need a local origin that behaves
like a CDN: HTTPS, cross-origin isolation headers, and a production build.

App-bound domains (`WKAppBoundDomains`) are part of the approved shell
configuration. They restrict which origins the WebView may navigate to.

## Decision

- The shell is a small UIKit `AppDelegate` that creates a Hotwire Native
  `Navigator`. `Navigator` owns one `WKWebView`, a `UINavigationController` and
  native back navigation. It starts at the configured HTTPS origin.
- The origin is the `WebOrigin` key in `Info.plist`, rendered from the
  `web_origin` Copier answer (`https://localhost:8443` by default). A
  `WEB_ORIGIN` launch environment variable overrides it for development and
  tests without rebuilding.
- `WKAppBoundDomains` contains the development host (`localhost`), and
  `limitsNavigationsToAppBoundDomains` is on. WKWebView only exposes service
  workers to app-bound domains; with the restriction off, the page reports
  "This browser does not support service workers." Add the deployed CDN host to
  the list when one exists and remove hosts that are no longer used. Do not
  silently widen the list.
- The production build is served by `app/scripts/serve-static-https.mjs`. It
  sends the same `Cross-Origin-Opener-Policy` and
  `Cross-Origin-Embedder-Policy` headers as Vite and serves
  `Service-Worker-Allowed: /`. This is a local stand-in for a CDN, not hosting.
  `app/scripts/make-dev-cert.sh` creates a throwaway CA and a `localhost`
  server certificate under `app/.local-https/` (gitignored).
- The simulator check installs that CA with `simctl keychain add-root-cert`
  before launching the app. No certificate or signing identity is committed.
- The UI test loads the app online, creates a task, terminates it, makes the
  origin unreachable (`/__control/offline`), and relaunches. The task must come
  from the service-worker cache and durable OPFS storage.
- "Offline" in the check means the app's origin refuses requests. The simulator
  shares the host network stack and `simctl` has no airplane mode, so the whole
  host is not disconnected. This is recorded as a limitation, not a pass for
  global network loss.
- The generated project has no native persistence. Task writes still go through
  the service worker, Hono, the database worker, Drizzle and SQLite WASM/OPFS.

## Consequences

- Chrome and the iOS shell load the same static build and the same TypeScript
  services. A Chrome pass is not evidence for WKWebView; the simulator check is.
- The local CA and control endpoints exist only in development tooling and are
  never part of the application bundle.
- The shell initially supports the iOS simulator only. Device signing, App Store
  distribution, CDN hosting and app-bound-domain enforcement against a real
  domain remain separate work with their own verification.
- Service-worker, OPFS and Web Locks support is asserted inside the real
  WKWebView by the About page diagnostic, not assumed from Safari support.
