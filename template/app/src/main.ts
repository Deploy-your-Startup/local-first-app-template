import "@hotwired/turbo";
import { Application } from "@hotwired/stimulus";
import { TaskFormController } from "./controllers/task-form-controller.ts";
import { databaseReady } from "./database.ts";
import "./style.css";

const tasksFrame = requireTasksFrame();

function requireTasksFrame(): HTMLElement {
  const frame = document.querySelector<HTMLElement>("#tasks");

  if (!frame) {
    throw new Error("The tasks frame is missing from the page.");
  }

  return frame;
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
}

void startLocalApp().catch((error: unknown) => {
  console.error(error);

  tasksFrame.textContent =
    error instanceof Error ? error.message : "Local startup failed.";
});
