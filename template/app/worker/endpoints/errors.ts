import type { ErrorHandler, NotFoundHandler } from "hono";
import { html } from "hono/html";
import type { AppEnv } from "./types.ts";

const frameMessage = (message: string) =>
  html`<turbo-frame id="tasks">
    <p class="error" role="alert">${message}</p>
  </turbo-frame>`;

export const handleNotFound: NotFoundHandler<AppEnv> = (context) =>
  context.html(frameMessage("Local route not found."), 404);

export const handleError: ErrorHandler<AppEnv> = (error, context) => {
  console.error(error);

  return context.html(frameMessage("The local request failed."), 500);
};
