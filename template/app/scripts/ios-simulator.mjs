#!/usr/bin/env node
/**
 * Local iOS simulator harness.
 *
 * Serves the static build, exposes it through a Cloudflare quick tunnel, and
 * runs the XCUITest suite against that HTTPS origin in two phases:
 *
 *   1. OnlineFlowTests      loads the origin and saves a task.
 *   2. OfflineRelaunchTests reopens the app after the tunnel is stopped and the
 *                           origin is verified unreachable.
 *
 * Nothing here is a template default: the tunnel URL is transient and is
 * written to `app/.local-ios/` (gitignored), never to committed sources.
 *
 * Usage:
 *   node scripts/ios-simulator.mjs --test   # serve, then run the UI tests
 *   node scripts/ios-simulator.mjs --serve  # serve until interrupted (Xcode)
 *
 * Environment:
 *   IOS_SIMULATOR_UDID  simulator to use (default: first available iPhone/iPad)
 *   CLOUDFLARED         cloudflared executable (default: from PATH)
 */
import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import process from "node:process";

import { parseWebOrigin } from "./web-origin.ts";

const appRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const projectRoot = join(appRoot, "..");
const xcodeProject = join(
  projectRoot,
  "native",
  "ios",
  "LocalFirstApp.xcodeproj",
);
const stateDirectory = join(appRoot, ".local-ios");
const previewURL = "http://127.0.0.1:4173";
const tunnelTimeoutMs = 120_000;
const offlineTimeoutMs = 60_000;

const children = new Set();
let stopping = false;

function stopAll() {
  for (const child of children) {
    if (child.exitCode === null && child.signalCode === null) {
      child.kill("SIGTERM");
    }
  }
  children.clear();
}

function track(child) {
  children.add(child);
  child.on("exit", () => children.delete(child));
  return child;
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { encoding: "utf8", ...options });

  if (result.status !== 0) {
    throw new Error(
      `${command} ${args.join(" ")} failed\n${result.stderr ?? ""}${result.stdout ?? ""}`,
    );
  }

  return result.stdout ?? "";
}

function hasCommand(command) {
  return spawnSync("command", ["-v", command], { shell: true }).status === 0;
}

function assertHostTools() {
  if (process.platform !== "darwin") {
    throw new Error("the iOS simulator checks require macOS");
  }

  if (!hasCommand("xcrun") || !hasCommand("xcodebuild")) {
    throw new Error(
      "Xcode is not available; install it and select it with xcode-select",
    );
  }

  if (!existsSync(join(appRoot, "dist", "index.html"))) {
    throw new Error("the static build is missing; run ./make.sh build first");
  }
}

async function waitForPreview() {
  for (let attempt = 0; attempt < 120; attempt += 1) {
    try {
      const response = await fetch(previewURL, {
        signal: AbortSignal.timeout(2_000),
      });

      if (response.ok) {
        const isolated =
          response.headers.get("cross-origin-opener-policy") ===
            "same-origin" &&
          response.headers.get("cross-origin-embedder-policy") ===
            "require-corp";

        if (!isolated) {
          throw new Error(
            "the preview server does not send COOP/COEP; OPFS would be unavailable",
          );
        }

        return;
      }
    } catch (error) {
      if (error instanceof Error && error.message.includes("COOP")) throw error;
    }

    await new Promise((resolve) => setTimeout(resolve, 500));
  }

  throw new Error(`the preview server did not answer on ${previewURL}`);
}

function startPreview() {
  const child = track(
    spawn("npm", ["run", "preview"], {
      cwd: appRoot,
      stdio: ["ignore", "inherit", "inherit"],
      env: process.env,
    }),
  );

  child.on("exit", (code) => {
    if (!stopping) {
      console.error(
        `ios-simulator: the preview server exited with code ${code}`,
      );
      process.exitCode = 1;
    }
  });

  return child;
}

async function startTunnel(cloudflared) {
  const child = track(
    spawn(cloudflared, ["tunnel", "--url", previewURL, "--no-autoupdate"], {
      cwd: appRoot,
      stdio: ["ignore", "pipe", "pipe"],
    }),
  );

  child.on("exit", (code) => {
    if (!stopping) {
      console.error(`ios-simulator: cloudflared exited with code ${code}`);
      process.exitCode = 1;
    }
  });

  let output = "";
  const tunnelOrigin = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(
        new Error(`no tunnel URL after ${tunnelTimeoutMs} ms:\n${output}`),
      );
    }, tunnelTimeoutMs);

    const inspect = (chunk) => {
      output += chunk.toString();
      const match = output.match(/https:\/\/[a-z0-9-]+\.trycloudflare\.com/);

      if (match) {
        clearTimeout(timer);
        resolve(match[0]);
      }
    };

    child.stdout.on("data", inspect);
    child.stderr.on("data", inspect);
  });

  const { origin, hostname } = parseWebOrigin(tunnelOrigin);

  for (let attempt = 0; attempt < 120; attempt += 1) {
    if (await originReachable(origin)) return { origin, hostname, child };
    await new Promise((resolve) => setTimeout(resolve, 1_000));
  }

  throw new Error(`the tunnel origin ${origin} never answered`);
}

async function originReachable(origin) {
  try {
    const response = await fetch(`${origin}/?probe=${Date.now()}`, {
      signal: AbortSignal.timeout(5_000),
      headers: { "cache-control": "no-store" },
    });

    return response.status < 400;
  } catch {
    return false;
  }
}

async function makeOriginUnreachable(tunnel) {
  stopping = true;
  tunnel.child.kill("SIGTERM");
  children.delete(tunnel.child);

  const deadline = Date.now() + offlineTimeoutMs;

  while (Date.now() < deadline) {
    if (!(await originReachable(tunnel.origin))) return;
    await new Promise((resolve) => setTimeout(resolve, 1_000));
  }

  throw new Error(
    `the origin ${tunnel.origin} is still reachable; cannot test offline relaunch`,
  );
}

function simulatorUDID() {
  if (process.env.IOS_SIMULATOR_UDID) return process.env.IOS_SIMULATOR_UDID;

  const devices = JSON.parse(
    run("xcrun", ["simctl", "list", "devices", "available", "-j"]),
  );

  for (const runtime of Object.values(devices.devices ?? {})) {
    const device = runtime.find(
      (candidate) =>
        candidate.isAvailable !== false &&
        (candidate.name.startsWith("iPhone") ||
          candidate.name.startsWith("iPad")),
    );

    if (device) return device.udid;
  }

  throw new Error(
    "no available iOS simulator; install a simulator runtime in Xcode",
  );
}

function bootSimulator(udid) {
  spawnSync("xcrun", ["simctl", "boot", udid]);
  run("xcrun", ["simctl", "bootstatus", udid, "-b"]);
}

function bundleIdentifier(udid) {
  const output = run(
    "xcrun",
    [
      "xcodebuild",
      "-project",
      xcodeProject,
      "-scheme",
      "LocalFirstApp",
      "-destination",
      `platform=iOS Simulator,id=${udid}`,
      "-showBuildSettings",
      "-json",
    ],
    { cwd: projectRoot },
  );

  const start = output.indexOf("[");
  const [settings] = JSON.parse(output.slice(start));
  const bundleID = settings.buildSettings.PRODUCT_BUNDLE_IDENTIFIER;

  if (!bundleID) throw new Error("could not read PRODUCT_BUNDLE_IDENTIFIER");

  return bundleID;
}

function runUITests({ udid, origin, hostname, only }) {
  console.log(`\n== ${only} ==`);
  const result = spawnSync(
    "xcrun",
    [
      "xcodebuild",
      "test",
      "-project",
      xcodeProject,
      "-scheme",
      "LocalFirstApp",
      "-destination",
      `platform=iOS Simulator,id=${udid}`,
      `-only-testing:LocalFirstAppUITests/${only}`,
      `WEB_ORIGIN=${origin}`,
      `APP_BOUND_DOMAIN=${hostname}`,
      "CODE_SIGNING_ALLOWED=NO",
    ],
    { cwd: projectRoot, stdio: "inherit", env: process.env },
  );

  return result.status ?? 1;
}

async function main() {
  const mode = process.argv.includes("--serve") ? "serve" : "test";
  assertHostTools();

  const cloudflared = process.env.CLOUDFLARED ?? "cloudflared";
  if (!hasCommand(cloudflared)) {
    throw new Error(
      `cloudflared is not available (${cloudflared}); install it and rerun, or set CLOUDFLARED`,
    );
  }

  rmSync(stateDirectory, { recursive: true, force: true });
  mkdirSync(stateDirectory, { recursive: true });

  const preview = startPreview();
  await waitForPreview();
  const tunnel = await startTunnel(cloudflared);

  const udid = simulatorUDID();
  bootSimulator(udid);
  const bundleID = bundleIdentifier(udid);

  writeFileSync(
    join(stateDirectory, "origin.json"),
    `${JSON.stringify(
      {
        origin: tunnel.origin,
        hostname: tunnel.hostname,
        bundleIdentifier: bundleID,
        simulator: udid,
      },
      null,
      2,
    )}\n`,
  );

  console.log(`origin ${tunnel.origin}`);
  console.log(`app-bound domain ${tunnel.hostname}`);
  console.log(`simulator ${udid}`);
  console.log(`bundle ${bundleID}`);
  console.log(`state ${join(stateDirectory, "origin.json")}`);

  if (mode === "serve") {
    console.log("serving until interrupted (start the app from Xcode)");
    await new Promise((resolve) => {
      process.on("SIGINT", resolve);
      process.on("SIGTERM", resolve);
    });
    return;
  }

  // Start from an empty app container so the persisted task belongs to this run.
  spawnSync("xcrun", ["simctl", "uninstall", udid, bundleID]);

  const online = runUITests({
    udid,
    origin: tunnel.origin,
    hostname: tunnel.hostname,
    only: "OnlineFlowTests",
  });

  if (online !== 0) {
    process.exitCode = online;
    preview.kill("SIGTERM");
    return;
  }

  await makeOriginUnreachable(tunnel);
  console.log(`origin ${tunnel.origin} is unreachable; relaunching the app`);

  const offline = runUITests({
    udid,
    origin: tunnel.origin,
    hostname: tunnel.hostname,
    only: "OfflineRelaunchTests",
  });

  if (offline !== 0) process.exitCode = offline;
  preview.kill("SIGTERM");
}

process.on("SIGINT", () => {
  stopAll();
  process.exit(130);
});
process.on("SIGTERM", () => {
  stopAll();
  process.exit(143);
});

main()
  .catch((error) => {
    console.error(
      `ios-simulator: ${error instanceof Error ? error.message : error}`,
    );
    process.exitCode = 1;
  })
  .finally(() => {
    stopAll();
  });
