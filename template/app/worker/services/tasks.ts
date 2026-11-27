import { desc } from "drizzle-orm";
import type { SqliteRemoteDatabase } from "drizzle-orm/sqlite-proxy";
import {
  databaseSchema,
  tasks,
  validateTaskTitle,
  type Task,
} from "../../shared/tasks.ts";

type TaskDatabase = SqliteRemoteDatabase<typeof databaseSchema>;

/** Raised when a title cannot be stored, so callers can render a form error. */
export class TaskTitleError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "TaskTitleError";
  }
}

export interface CreateTaskInput {
  title: string;
  createdAt?: string;
}

export interface TaskService {
  list(): Promise<Task[]>;
  create(input: CreateTaskInput): Promise<Task>;
}

export interface TaskServiceOptions {
  /** Injectable clock so tests can assert the stored timestamp. */
  now?: () => Date;
}

export function createTaskService(
  db: TaskDatabase,
  { now = () => new Date() }: TaskServiceOptions = {},
): TaskService {
  return {
    async list() {
      const rows = await db.select().from(tasks).orderBy(desc(tasks.id));

      return rows.map((row) => ({
        id: row.id,
        title: row.title,
        createdAt: row.createdAt,
      }));
    },

    async create({ title, createdAt }) {
      const validation = validateTaskTitle(title);

      if (!validation.ok) {
        throw new TaskTitleError(validation.error);
      }

      const [row] = await db
        .insert(tasks)
        .values({
          title: validation.title,
          createdAt: createdAt ?? now().toISOString(),
        })
        .returning();

      if (!row) {
        throw new Error("The task could not be stored.");
      }

      return { id: row.id, title: row.title, createdAt: row.createdAt };
    },
  };
}
