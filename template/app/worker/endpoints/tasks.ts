import type { Handler } from "hono";
import { html } from "hono/html";
import {
  TASK_TITLE_MAX_LENGTH,
  validateTaskTitle,
  type Task,
  type TaskServiceRequest,
  type TaskServiceResponse,
} from "../../shared/tasks.ts";
import type { AppEnv } from "./types.ts";

declare const self: ServiceWorkerGlobalScope;

const SERVICE_TIMEOUT_MS = 5_000;

/**
 * The service worker cannot reach OPFS, so it asks the requesting page to relay
 * the request to its database worker and waits for the typed response.
 */
export async function callTaskService(
  clientId: string,
  request: TaskServiceRequest,
): Promise<TaskServiceResponse> {
  if (!clientId) throw new Error("The requesting page is unavailable.");

  const client = await self.clients.get(clientId);

  if (!client) throw new Error("The requesting page is unavailable.");

  return new Promise((resolve, reject) => {
    const channel = new MessageChannel();
    const timeout = setTimeout(() => {
      channel.port1.close();
      reject(new Error("The local database did not respond."));
    }, SERVICE_TIMEOUT_MS);

    channel.port1.addEventListener(
      "message",
      ({ data }: MessageEvent<TaskServiceResponse>) => {
        clearTimeout(timeout);
        channel.port1.close();
        resolve(data);
      },
      { once: true },
    );
    channel.port1.start();

    client.postMessage(request, [channel.port2]);
  });
}

interface TaskListView {
  tasks: Task[];
  title?: string;
  error?: string;
}

export function renderTasks({ tasks, title = "", error }: TaskListView) {
  return html`<turbo-frame id="tasks">
    <form
      class="task-form"
      action="/local/tasks"
      method="post"
      data-controller="task-form"
    >
      <label for="task-title">Task title</label>
      <input
        id="task-title"
        name="title"
        type="text"
        autocomplete="off"
        value="${title}"
        aria-describedby="task-title-hint"
        required
        data-task-form-target="title"
      />
      <p class="hint" id="task-title-hint">
        Up to ${TASK_TITLE_MAX_LENGTH} characters.
      </p>
      <button type="submit" data-task-form-target="submit">Add task</button>
    </form>
    ${error ? html`<p class="error" role="alert">${error}</p>` : ""}
    <ul class="task-list">
      ${tasks.map(
        (task) =>
          html`<li class="task" data-task-id="${String(task.id)}">
            <span class="task-title">${task.title}</span>
          </li>`,
      )}
    </ul>
    ${
      tasks.length === 0
        ? html`<p class="empty">No tasks yet.</p>`
        : html`<p class="status" role="status">
            ${String(tasks.length)} task${tasks.length === 1 ? "" : "s"} stored
            in this browser.
          </p>`
    }
  </turbo-frame>`;
}

export const getTasks: Handler<AppEnv> = async (context) => {
  const response = await callTaskService(context.env.clientId, {
    type: "task-service",
    method: "list",
  });

  if (!response.ok) {
    return context.html(renderTasks({ tasks: [], error: response.error }), 500);
  }

  if (response.method !== "list") {
    return context.html(
      renderTasks({ tasks: [], error: "Unexpected database response." }),
      500,
    );
  }

  return context.html(renderTasks({ tasks: response.tasks }));
};

export const postTasks: Handler<AppEnv> = async (context) => {
  const body = await context.req.parseBody();
  const submitted = typeof body.title === "string" ? body.title : "";
  const validation = validateTaskTitle(submitted);

  if (!validation.ok) {
    const listed = await callTaskService(context.env.clientId, {
      type: "task-service",
      method: "list",
    });

    if (!listed.ok || listed.method !== "list") {
      return context.html(
        renderTasks({ tasks: [], error: validation.error }),
        500,
      );
    }

    // Turbo replaces the frame on 422, so the user keeps their input.
    return context.html(
      renderTasks({
        tasks: listed.tasks,
        title: submitted,
        error: validation.error,
      }),
      422,
    );
  }

  const created = await callTaskService(context.env.clientId, {
    type: "task-service",
    method: "create",
    title: validation.title,
  });

  if (!created.ok) {
    const listed = await callTaskService(context.env.clientId, {
      type: "task-service",
      method: "list",
    });

    return context.html(
      renderTasks({
        tasks: listed.ok && listed.method === "list" ? listed.tasks : [],
        title: submitted,
        error: created.error,
      }),
      500,
    );
  }

  return context.redirect("/local/tasks", 303);
};
