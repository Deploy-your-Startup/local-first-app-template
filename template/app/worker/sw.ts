import { Hono } from "hono";
import { createHandlerBoundToURL, precacheAndRoute } from "workbox-precaching";
import { NavigationRoute, registerRoute } from "workbox-routing";
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

// The native WebView must reopen the cached shell when the origin is
// unreachable, which requires answering navigation requests from the precache.
// Local routes and the SQLite runtime are served by the worker itself, so they
// are not navigation fallbacks. The development worker has no precache and is
// never offline-tested.
if (import.meta.env.PROD) {
  registerRoute(
    new NavigationRoute(createHandlerBoundToURL("/index.html"), {
      denylist: [/^\/local\//, /^\/sqlite\//],
    }),
  );
}

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
