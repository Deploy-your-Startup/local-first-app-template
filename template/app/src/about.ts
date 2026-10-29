/**
 * Report whether the current WebView provides the platform features the
 * local database needs. The simulator UI checks read this line to prove the
 * actual WKWebView configuration, not an assumed capability.
 */
const runtime = document.querySelector<HTMLElement>("#runtime");

async function hasServiceWorkerController(): Promise<boolean> {
  if (!("serviceWorker" in navigator)) return false;
  if (navigator.serviceWorker.controller) return true;

  // A fresh document can be handed to an already-active worker asynchronously,
  // and an update in progress can briefly report no active worker.
  return new Promise<boolean>((resolve) => {
    const deadline = Date.now() + 5_000;

    const poll = () => {
      if (navigator.serviceWorker.controller) {
        resolve(true);
      } else if (Date.now() >= deadline) {
        resolve(false);
      } else {
        window.setTimeout(poll, 100);
      }
    };

    navigator.serviceWorker.addEventListener(
      "controllerchange",
      () => resolve(true),
      { once: true },
    );
    window.setTimeout(poll, 0);
  });
}

async function checkRuntime(): Promise<void> {
  if (!runtime) return;

  const missing: string[] = [];

  if (!window.crossOriginIsolated) missing.push("cross-origin isolation");
  if (!(await hasServiceWorkerController())) missing.push("service worker");
  if (!("locks" in navigator)) missing.push("web locks");
  if (!navigator.storage?.getDirectory) missing.push("OPFS");

  if (missing.length === 0) {
    try {
      await navigator.storage.getDirectory();
    } catch {
      missing.push("OPFS access");
    }
  }

  runtime.textContent =
    missing.length === 0
      ? "Runtime: all available"
      : `Runtime: unavailable (${missing.join(", ")})`;
}

void checkRuntime();
