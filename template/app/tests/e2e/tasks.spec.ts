import { expect, test, type Page } from "@playwright/test";

const addTaskButton = (page: Page) =>
  page.getByRole("button", { name: "Add task" });
const titleField = (page: Page) => page.getByLabel("Task title");
const taskTitles = (page: Page) => page.locator(".task-title");

async function openApp(page: Page) {
  await page.goto("/");

  // The frame is only pointed at /local/tasks once the database worker is ready
  // and the service worker controls the page.
  await expect(addTaskButton(page)).toBeVisible();
  await expect(page.locator(".empty")).toHaveText("No tasks yet.");
}

test.describe("local-first tasks", () => {
  test("GIVEN an empty database WHEN a task is added THEN it survives a reload", async ({
    page,
  }) => {
    await openApp(page);

    await titleField(page).fill("Buy oat milk");
    await addTaskButton(page).click();

    await expect(taskTitles(page)).toHaveText(["Buy oat milk"]);

    await page.reload();

    await expect(taskTitles(page)).toHaveText(["Buy oat milk"]);
    await expect(page.locator(".empty")).toHaveCount(0);
  });

  test("GIVEN the newest task exists WHEN it is added THEN it is listed first", async ({
    page,
  }) => {
    await openApp(page);

    await titleField(page).fill("First task");
    await addTaskButton(page).click();
    await expect(taskTitles(page)).toHaveText(["First task"]);

    await titleField(page).fill("Second task");
    await addTaskButton(page).click();
    await expect(taskTitles(page)).toHaveText(["Second task", "First task"]);

    await page.reload();
    await expect(taskTitles(page)).toHaveText(["Second task", "First task"]);
  });

  test("GIVEN a whitespace-only title WHEN it is submitted THEN nothing is stored", async ({
    page,
  }) => {
    await openApp(page);

    await titleField(page).fill("   ");
    await addTaskButton(page).click();

    await expect(page.getByRole("alert")).toHaveText("Enter a task title.");
    await expect(page.locator(".empty")).toHaveText("No tasks yet.");

    await page.reload();

    await expect(taskTitles(page)).toHaveCount(0);
    await expect(page.locator(".empty")).toHaveText("No tasks yet.");
  });

  test("WHEN the application starts THEN it is cross-origin isolated and served by its service worker", async ({
    page,
  }) => {
    await openApp(page);

    // OPFS is only available to a cross-origin isolated page, which the dev and
    // static servers both provide through COOP/COEP headers.
    expect(await page.evaluate(() => window.crossOriginIsolated)).toBe(true);
    expect(
      await page.evaluate(() => navigator.serviceWorker.controller !== null),
    ).toBe(true);
  });
});
