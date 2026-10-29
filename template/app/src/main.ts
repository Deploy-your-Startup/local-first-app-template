import "@hotwired/turbo";
import { Application } from "@hotwired/stimulus";
import { TaskFormController } from "./controllers/task-form-controller.ts";
import { databaseReady, readDatabaseDiagnostics } from "./database.ts";
import { describeRuntime, type RuntimeReport } from "../shared/runtime.ts";
import "./style.css";

const tasksFrame = requireTasksFrame();
const runtimeStatus = requireRuntimeStatus();

function requireTasksFrame(): HTMLElement {
  const frame = document.querySelector<HTMLElement>("#tasks");

  if (!frame) {
    throw new Error("The tasks frame is missing from the page.");
  }

  return frame;
}

function requireRuntimeStatus(): HTMLElement {
  const status = document.querySelector<HTMLElement>(
    "[data-testid='runtime-status']",
  );

  if (!status) {
    throw new Error("The runtime status element is missing from the page.");
  }

  return status;
}

const application = Application.start();
application.register("task-form", TaskFormController);

function waitForControllerChange(
  workers: ServiceWorkerContainer,
  previousController: ServiceWorker | null,
): Promise<void> {
  if (workers.controller && workers.controller !== previousController) {
    return Promise.resolve();
  }

  return new Promise<void>((resolve, reject) => {
    const timeout = window.setTimeout(() => {
      workers.removeEventListener("controllerchange", check);
      reject(new Error("The service worker is not ready. Reload the page."));
    }, 15_000);

    const check = () => {
      if (!workers.controller || workers.controller === previousController) {
        return;
      }

      window.clearTimeout(timeout);
      workers.removeEventListener("controllerchange", check);
      resolve();
    };

    workers.addEventListener("controllerchange", check);
    check();
  });
}

async function registerServiceWorker(): Promise<void> {
  if (!("serviceWorker" in navigator)) {
    throw new Error("This browser does not support service workers.");
  }

  const workers = navigator.serviceWorker;
  const previousController = workers.controller;

  const registration = await workers.register(
    import.meta.env.DEV ? "/dev-sw.js?dev-sw" : "/sw.js",
    {
      scope: "/",
      type: import.meta.env.DEV ? "module" : "classic",
    },
  );

  try {
    await registration.update();
  } catch (error) {
    if (!workers.controller) throw error;

    console.warn(
      "The service worker update failed; using the installed worker.",
      error,
    );
  }

  if (!workers.controller || registration.installing || registration.waiting) {
    await waitForControllerChange(workers, previousController);
  }
}

async function startLocalApp(): Promise<void> {
  // The database worker starts on import; surface storage failures before the
  // frame tries to read tasks.
  await databaseReady;
  await registerServiceWorker();

  tasksFrame.setAttribute("src", "/local/tasks");

  await reportRuntime();
}

async function hasOpfs(): Promise<boolean> {
  if (typeof navigator.storage?.getDirectory !== "function") return false;

  try {
    await navigator.storage.getDirectory();
    return true;
  } catch {
    return false;
  }
}

/**
 * Renders what the page and its database worker can actually do. The browser
 * and the native WebView show the same facts, so neither platform claims a
 * capability that its runtime does not provide.
 */
async function reportRuntime(): Promise<void> {
  try {
    const [database, opfs] = await Promise.all([
      readDatabaseDiagnostics(),
      hasOpfs(),
    ]);

    const report: RuntimeReport = {
      secureContext: window.isSecureContext,
      crossOriginIsolated: window.crossOriginIsolated,
      serviceWorkerControlled: navigator.serviceWorker.controller !== null,
      webLocks: Boolean(navigator.locks),
      opfs,
      sqliteVersion:
        "sqliteVersion" in database ? database.sqliteVersion : null,
    };

    const description = describeRuntime(report);
    runtimeStatus.textContent = description.text;
    runtimeStatus.dataset.runtime = description.available
      ? "available"
      : "degraded";
  } catch (error) {
    console.error(error);
    runtimeStatus.textContent = `Runtime unavailable: ${
      error instanceof Error ? error.message : "unknown error"
    }`;
    runtimeStatus.dataset.runtime = "unavailable";
  }
}

void startLocalApp().catch((error: unknown) => {
  console.error(error);

  tasksFrame.textContent =
    error instanceof Error ? error.message : "Local startup failed.";
  runtimeStatus.textContent = "Runtime unavailable: local startup failed.";
  runtimeStatus.dataset.runtime = "unavailable";
});
