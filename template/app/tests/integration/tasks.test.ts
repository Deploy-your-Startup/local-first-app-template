import assert from "node:assert/strict";
import { DatabaseSync, type SQLInputValue } from "node:sqlite";
import { test } from "node:test";

import { drizzle } from "drizzle-orm/sqlite-proxy";

import {
  DATABASE_SCHEMA_SQL,
  EMPTY_TITLE_ERROR,
  TASK_TITLE_MAX_LENGTH,
  databaseSchema,
} from "../../shared/tasks.ts";
import {
  TaskTitleError,
  createTaskService,
} from "../../worker/services/tasks.ts";

const CREATED_AT = "2026-01-02T03:04:05.000Z";

/**
 * Builds the real Drizzle service over a real SQLite database. `node:sqlite` is
 * the Node.js build of the same engine the browser runs through WASM, so the
 * service and the schema are exercised without mocks.
 */
function createTestDatabase() {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(DATABASE_SCHEMA_SQL);

  const db = drizzle(
    async (sql, params, method) => {
      const statement = sqlite.prepare(sql);
      const args = params as SQLInputValue[];

      if (method === "run") {
        statement.run(...args);
        return { rows: [] };
      }

      const values = statement
        .all(...args)
        .map((row) => Object.values(row as Record<string, unknown>));

      return { rows: method === "get" ? (values[0] ?? []) : values };
    },
    { schema: databaseSchema },
  );

  const service = createTaskService(db, { now: () => new Date(CREATED_AT) });

  return { sqlite, service };
}

function storedTitles(sqlite: DatabaseSync): string[] {
  return sqlite
    .prepare("SELECT title FROM tasks ORDER BY id")
    .all()
    .map((row) => (row as { title: string }).title);
}

test("GIVEN no tasks WHEN a task is created THEN it is listed and stored", async () => {
  const { sqlite, service } = createTestDatabase();

  assert.deepEqual(await service.list(), []);

  const created = await service.create({ title: "Buy oat milk" });
  assert.deepEqual(created, {
    id: 1,
    title: "Buy oat milk",
    createdAt: CREATED_AT,
  });

  assert.deepEqual(await service.list(), [created]);
  assert.deepEqual(storedTitles(sqlite), ["Buy oat milk"]);

  sqlite.close();
});

test("WHEN a title has surrounding and repeated whitespace THEN the stored title is normalised", async () => {
  const { sqlite, service } = createTestDatabase();

  const created = await service.create({ title: "  Buy   oat \t milk  " });

  assert.equal(created.title, "Buy oat milk");
  assert.deepEqual(storedTitles(sqlite), ["Buy oat milk"]);

  sqlite.close();
});

test("WHEN tasks are listed THEN the newest task comes first", async () => {
  const { sqlite, service } = createTestDatabase();

  await service.create({ title: "First task" });
  await service.create({ title: "Second task" });

  assert.deepEqual(
    (await service.list()).map((task) => task.title),
    ["Second task", "First task"],
  );

  sqlite.close();
});

test("GIVEN no tasks WHEN an empty title is created THEN nothing is stored", async () => {
  const { sqlite, service } = createTestDatabase();

  await assert.rejects(() => service.create({ title: "   " }), {
    name: TaskTitleError.name,
    message: EMPTY_TITLE_ERROR,
  });
  await assert.rejects(() => service.create({ title: "" }), {
    name: TaskTitleError.name,
  });

  assert.deepEqual(storedTitles(sqlite), []);
  assert.deepEqual(await service.list(), []);

  sqlite.close();
});

test("GIVEN no tasks WHEN a too long title is created THEN nothing is stored", async () => {
  const { sqlite, service } = createTestDatabase();

  await assert.rejects(
    () => service.create({ title: "a".repeat(TASK_TITLE_MAX_LENGTH + 1) }),
    { name: TaskTitleError.name },
  );

  assert.deepEqual(storedTitles(sqlite), []);

  sqlite.close();
});

test("WHEN a title at the length limit is created THEN it is stored", async () => {
  const { sqlite, service } = createTestDatabase();

  const title = "a".repeat(TASK_TITLE_MAX_LENGTH);
  const created = await service.create({ title });

  assert.equal(created.title.length, TASK_TITLE_MAX_LENGTH);

  sqlite.close();
});
