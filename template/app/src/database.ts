import {
  type DatabaseDiagnosticsRequest,
  type DatabaseDiagnosticsResponse,
} from "../shared/runtime.ts";
import { isTaskServiceRequest } from "../shared/tasks.ts";

type DatabaseStatus =
  { type: "database-ready" } | { type: "database-error"; error: string };

const DIAGNOSTICS_TIMEOUT_MS = 5_000;

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

/**
 * Asks the database worker which SQLite runtime it actually opened. This is
 * reported in the visible runtime status instead of being assumed.
 */
export function readDatabaseDiagnostics(): Promise<DatabaseDiagnosticsResponse> {
  return new Promise((resolve) => {
    const channel = new MessageChannel();
    const timeout = window.setTimeout(() => {
      channel.port1.close();
      resolve({
        type: "database-diagnostics",
        error: "The database worker did not answer.",
      });
    }, DIAGNOSTICS_TIMEOUT_MS);

    channel.port1.addEventListener(
      "message",
      ({ data }: MessageEvent<DatabaseDiagnosticsResponse>) => {
        window.clearTimeout(timeout);
        channel.port1.close();
        resolve(data);
      },
      { once: true },
    );
    channel.port1.start();

    const request: DatabaseDiagnosticsRequest = {
      type: "database-diagnostics",
    };
    worker.postMessage(request, [channel.port2]);
  });
}
