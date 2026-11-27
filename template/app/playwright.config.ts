import { defineConfig, devices } from "@playwright/test";

const staticBuild = process.env.E2E_SERVER === "static";
const port = staticBuild ? 4173 : 5173;

export default defineConfig({
  testDir: "./tests/e2e",
  // One database owner per context; keep scenarios sequential and explicit.
  fullyParallel: false,
  workers: 1,
  expect: {
    timeout: 15_000,
  },
  use: {
    baseURL: `http://127.0.0.1:${port}`,
    serviceWorkers: "allow",
    trace: "on-first-retry",
  },
  webServer: {
    command: staticBuild ? "npm run preview" : "npm run dev",
    url: `http://127.0.0.1:${port}`,
    reuseExistingServer: !process.env.CI,
    timeout: 60_000,
  },
  projects: [
    {
      name: staticBuild ? "chromium-static" : "chromium-dev",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
});
