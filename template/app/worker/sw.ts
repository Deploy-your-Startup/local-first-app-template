import { Hono } from "hono";
import { precacheAndRoute } from "workbox-precaching";
import { handleError, handleNotFound } from "./endpoints/errors.ts";
import { getTasks, postTasks } from "./endpoints/tasks.ts";
import type { AppEnv } from "./endpoints/types.ts";

declare const self: ServiceWorkerGlobalScope & {
  __WB_MANIFEST: Array<{
    url: string;
    revision: string | null;
  }>;
};

precacheAndRoute(self.__WB_MANIFEST);

const app = new Hono<AppEnv>().basePath("/local");

app.get("/tasks", getTasks);
app.post("/tasks", postTasks);

app.notFound(handleNotFound);
app.onError(handleError);

self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);

  if (
    url.origin === self.location.origin &&
    url.pathname.startsWith("/local/")
  ) {
    event.respondWith(
      app.fetch(event.request, {
        clientId: event.clientId,
      }),
    );
  }
});

self.addEventListener("install", (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim());
});
