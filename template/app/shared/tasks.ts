import { integer, sqliteTable, text } from "drizzle-orm/sqlite-core";

/** Longest accepted title, counted after whitespace is normalised. */
export const TASK_TITLE_MAX_LENGTH = 120;

export const EMPTY_TITLE_ERROR = "Enter a task title.";

export const tasks = sqliteTable("tasks", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  title: text("title").notNull(),
  createdAt: text("created_at").notNull(),
});

export const databaseSchema = { tasks };

/**
 * The initial schema. The database worker executes this statement and the
 * integration tests execute the same statement, so the two cannot drift.
 */
export const DATABASE_SCHEMA_SQL = `
CREATE TABLE IF NOT EXISTS tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  created_at TEXT NOT NULL
);
`;

export interface Task {
  id: number;
  title: string;
  createdAt: string;
}

export interface CreateTaskRequest {
  type: "task-service";
  method: "create";
  title: string;
}

export interface ListTasksRequest {
  type: "task-service";
  method: "list";
}

export type TaskServiceRequest = CreateTaskRequest | ListTasksRequest;

export type TaskServiceResponse =
  | { ok: true; method: "list"; tasks: Task[] }
  | { ok: true; method: "create"; task: Task }
  | { ok: false; error: string };

export type TitleValidation =
  { ok: true; title: string } | { ok: false; error: string };

/**
 * Trims surrounding whitespace, collapses interior runs and enforces a length
 * limit. An invalid title must never reach storage.
 */
export function validateTaskTitle(value: unknown): TitleValidation {
  if (typeof value !== "string") {
    return { ok: false, error: EMPTY_TITLE_ERROR };
  }

  const title = value.replace(/\s+/g, " ").trim();

  if (title.length === 0) {
    return { ok: false, error: EMPTY_TITLE_ERROR };
  }

  if (title.length > TASK_TITLE_MAX_LENGTH) {
    return {
      ok: false,
      error: `Keep the title under ${TASK_TITLE_MAX_LENGTH} characters.`,
    };
  }

  return { ok: true, title };
}

export function isTaskServiceRequest(
  value: unknown,
): value is TaskServiceRequest {
  if (!value || typeof value !== "object") return false;

  const request = value as {
    type?: unknown;
    method?: unknown;
    title?: unknown;
  };

  if (request.type !== "task-service") return false;
  if (request.method === "list") return true;

  return request.method === "create" && typeof request.title === "string";
}
