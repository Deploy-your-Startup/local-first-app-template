import { drizzle } from "drizzle-orm/sqlite-proxy";
import {
  DATABASE_FILE,
  DATABASE_LOCK_NAME,
  DATABASE_POOL_NAME,
} from "../shared/app.ts";
import {
  DATABASE_SCHEMA_SQL,
  databaseSchema,
  isTaskServiceRequest,
  type TaskServiceResponse,
} from "../shared/tasks.ts";
import { createTaskService, type TaskService } from "./services/tasks.ts";

interface SQLiteExecOptions {
  sql: string;
  bind: unknown[];
  rowMode: "array";
  returnValue: "resultRows";
}

interface SQLiteDatabase {
  exec(sql: string): void;
  exec(options: SQLiteExecOptions): unknown[][];
  transaction(callback: () => void): void;
}

interface SQLitePool {
  OpfsSAHPoolDb: new (filename: string) => SQLiteDatabase;
}

interface SQLiteApi {
  version: {
    libVersion: string;
  };
  installOpfsSAHPoolVfs(options: {
    name: string;
    preserveOnInitFailure: boolean;
  }): Promise<SQLitePool>;
}

interface DatabaseContext {
  taskService: TaskService;
  version: string;
}

type SQLiteGlobal = typeof globalThis & {
  sqlite3ApiConfig: {
    disable: {
      vfs: Record<string, boolean>;
    };
  };
};

type SQLiteInitializer = (options: {
  locateFile: (path: string) => string;
}) => Promise<SQLiteApi>;

const EXPECTED_SQLITE_VERSION = "3.54.1";
const LOCK_TIMEOUT_MS = 5_000;
const REQUEST_TIMEOUT_MS = 5_000;

const worker = self as DedicatedWorkerGlobalScope;

// Use the SAH pool without loading the other OPFS implementations.
(globalThis as SQLiteGlobal).sqlite3ApiConfig = {
  disable: {
    vfs: {
      opfs: true,
      "opfs-wl": true,
      kvvfs: true,
    },
  },
};

let resolveDatabase!: (value: DatabaseContext) => void;
let rejectDatabase!: (reason?: unknown) => void;

const databaseReady = new Promise<DatabaseContext>((resolve, reject) => {
  resolveDatabase = resolve;
  rejectDatabase = reject;
});

// Startup failures are reported to the page below; this keeps the rejection
// from being reported as unhandled while the page is still loading.
void databaseReady.catch(() => {});

async function openDatabase() {
  if (!navigator.locks) {
    throw new Error("This browser does not support Web Locks.");
  }

  const abort = new AbortController();
  const timeout = setTimeout(() => abort.abort(), LOCK_TIMEOUT_MS);

  await navigator.locks
    .request(
      DATABASE_LOCK_NAME,
      { mode: "exclusive", signal: abort.signal },
      async () => {
        clearTimeout(timeout);

        // Served as a static asset so the dev server and the static build load
        // the same pinned SQLite runtime.
        const sqliteBase = new URL("/sqlite/3.54.1/", self.location.origin)
          .href;
        const { default: initialize } = (await import(
          /* @vite-ignore */ `${sqliteBase}sqlite3.mjs`
        )) as { default: SQLiteInitializer };

        const sqlite3 = await initialize({
          locateFile: () => `${sqliteBase}sqlite3.wasm`,
        });

        if (sqlite3.version.libVersion !== EXPECTED_SQLITE_VERSION) {
          throw new Error(
            `Unexpected SQLite runtime version: ${sqlite3.version.libVersion}`,
          );
        }

        const pool = await sqlite3.installOpfsSAHPoolVfs({
          name: DATABASE_POOL_NAME,
          preserveOnInitFailure: true,
        });

        const db = new pool.OpfsSAHPoolDb(DATABASE_FILE);

        db.exec(`
          PRAGMA synchronous = FULL;
          PRAGMA foreign_keys = ON;
        `);

        db.transaction(() => {
          db.exec(DATABASE_SCHEMA_SQL);
        });

        const orm = drizzle(
          async (sql, params, method) => {
            if (method === "run") {
              db.exec({
                sql,
                bind: params,
                rowMode: "array",
                returnValue: "resultRows",
              });
              return { rows: [] };
            }

            const rows = db.exec({
              sql,
              bind: params,
              rowMode: "array",
              returnValue: "resultRows",
            });

            return { rows: method === "get" ? (rows[0] ?? []) : rows };
          },
          { schema: databaseSchema },
        );

        resolveDatabase({
          taskService: createTaskService(orm),
          version: sqlite3.version.libVersion,
        });

        worker.postMessage({ type: "database-ready" });

        // Hold the lock for this worker's lifetime: one tab owns the database.
        await new Promise(() => {});
      },
    )
    .catch((error) => {
      clearTimeout(timeout);

      if (abort.signal.aborted) {
        throw new Error(
          "Another window of this app already has the database open. Close it and reload.",
        );
      }

      throw error;
    });
}

void openDatabase().catch((error) => {
  console.error(error);
  rejectDatabase(error);

  worker.postMessage({
    type: "database-error",
    error: error instanceof Error ? error.message : "Database startup failed.",
  });
});

worker.addEventListener("message", async (event: MessageEvent<unknown>) => {
  const port = event.ports[0];

  if (!port || !isTaskServiceRequest(event.data)) return;

  const request = event.data;

  try {
    const { taskService } = await Promise.race([
      databaseReady,
      new Promise<never>((_, reject) => {
        setTimeout(
          () => reject(new Error("The local database is not ready.")),
          REQUEST_TIMEOUT_MS,
        );
      }),
    ]);

    const response: TaskServiceResponse =
      request.method === "list"
        ? { ok: true, method: "list", tasks: await taskService.list() }
        : {
            ok: true,
            method: "create",
            task: await taskService.create({ title: request.title }),
          };

    port.postMessage(response);
  } catch (error) {
    console.error(error);

    const response: TaskServiceResponse = {
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : "The local database operation failed.",
    };

    port.postMessage(response);
  } finally {
    port.close();
  }
});
