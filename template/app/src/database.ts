import { isTaskServiceRequest } from "../shared/tasks.ts";

type DatabaseStatus =
  { type: "database-ready" } | { type: "database-error"; error: string };

/**
 * Starts the database worker immediately. The worker owns SQLite for this tab's
 * lifetime, so importing this module is what claims database ownership.
 */
const worker = new Worker(new URL("../worker/database.ts", import.meta.url), {
  type: "module",
});

export const databaseReady = new Promise<void>((resolve, reject) => {
  worker.addEventListener(
    "message",
    ({ data }: MessageEvent<DatabaseStatus>) => {
      if (data.type === "database-ready") {
        resolve();
      } else if (data.type === "database-error") {
        reject(new Error(data.error));
      }
    },
  );

  worker.addEventListener("error", (event) => {
    reject(new Error(event.message));
  });
});

// Relay database requests from the service worker to the database worker.
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.addEventListener("message", (event) => {
    const port = event.ports[0];

    if (!port || !isTaskServiceRequest(event.data)) return;

    worker.postMessage(event.data, [port]);
  });
}
