import { expect, test } from "@playwright/test";

test.describe("offline and runtime capabilities", () => {
  test("GIVEN a saved task WHEN the browser goes offline and reloads THEN the task is still shown from the cache", async ({
    context,
    page,
  }) => {
    test.skip(
      !process.env.E2E_SERVER,
      "Offline caching is only provided by a production build.",
    );

    await page.goto("/");

    const title = page.getByLabel("Task title");
    const add = page.getByRole("button", { name: "Add task" });
    await expect(add).toBeVisible();

    await title.fill("Read offline");
    await add.click();
    await expect(page.locator(".task-title")).toHaveText(["Read offline"]);

    await context.setOffline(true);
    await page.reload();

    await expect(page.getByRole("button", { name: "Add task" })).toBeVisible();
    await expect(page.locator(".task-title")).toHaveText(["Read offline"]);
  });

  test("WHEN the About page opens THEN it reports the runtime features the local database needs", async ({
    page,
  }) => {
    await page.goto("/");

    // Wait for startup to finish: registering the service worker and starting
    // the database is what makes the page controlled.
    await expect(page.getByRole("button", { name: "Add task" })).toBeVisible();

    await page.getByRole("link", { name: "About this app" }).click();

    await expect(page).toHaveURL(/\/about\.html$/);
    await expect(page.locator("#runtime")).toHaveText("Runtime: all available");

    await page.getByRole("link", { name: "Back to tasks" }).click();
    await expect(page).toHaveURL(/\/$/);
    await expect(page.getByRole("button", { name: "Add task" })).toBeVisible();
  });
});
