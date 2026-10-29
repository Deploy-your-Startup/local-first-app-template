import { defineConfig, devices } from "@playwright/test";

const server = process.env.E2E_SERVER ?? "dev";
const staticBuild = server === "static";
const httpsBuild = server === "https";
const port = staticBuild ? 4173 : httpsBuild ? 8443 : 5173;
const origin = httpsBuild
  ? `https://localhost:${port}`
  : `http://127.0.0.1:${port}`;

const commands = {
  dev: "npm run dev",
  static: "npm run preview",
  https: "npm run serve:https",
};

export default defineConfig({
  testDir: "./tests/e2e",
  // One database owner per context; keep scenarios sequential and explicit.
  fullyParallel: false,
  workers: 1,
  expect: {
    timeout: 15_000,
  },
  use: {
    baseURL: origin,
    serviceWorkers: "allow",
    // Only the local self-signed development certificate is affected.
    ignoreHTTPSErrors: httpsBuild,
    launchOptions: httpsBuild
      ? {
          // Service-worker script fetches do not honour ignoreHTTPSErrors.
          args: ["--ignore-certificate-errors"],
        }
      : undefined,
    trace: "on-first-retry",
  },
  webServer: {
    command: commands[server as keyof typeof commands] ?? commands.dev,
    // Wait for the listening socket: the HTTPS build uses a self-signed
    // development certificate that Playwright's health check would reject.
    port,
    reuseExistingServer: !process.env.CI,
    timeout: 60_000,
  },
  projects: [
    {
      name: httpsBuild
        ? "chromium-https-static"
        : staticBuild
          ? "chromium-static"
          : "chromium-dev",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
});
