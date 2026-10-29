/**
 * Derives the WebView origin and the app-bound domain from one configured URL.
 *
 * `WKAppBoundDomains` must contain exactly the hostname of the origin the shell
 * loads: no scheme, no port, no path. Both values are derived from the same
 * string so they cannot drift apart when the tunnel URL changes.
 */
import { pathToFileURL } from "node:url";

export interface WebOrigin {
  /** Normalised origin, for example `https://tasks.example.com`. */
  origin: string;
  /** Hostname only, for `WKAppBoundDomains`. */
  hostname: string;
}

const LOOPBACK_HOSTNAMES = new Set(["localhost", "127.0.0.1", "[::1]"]);

export function parseWebOrigin(value: string): WebOrigin {
  let url: URL;

  try {
    url = new URL(value);
  } catch {
    throw new Error(`The web origin is not a valid URL: ${value}`);
  }

  const loopback = LOOPBACK_HOSTNAMES.has(url.hostname);

  if (url.protocol !== "https:" && !(url.protocol === "http:" && loopback)) {
    throw new Error(
      "The web origin must use https; plain http is only accepted on a loopback host for local development.",
    );
  }

  if (
    (url.pathname !== "/" && url.pathname !== "") ||
    url.search !== "" ||
    url.hash !== ""
  ) {
    throw new Error(
      "The web origin must not contain a path, query or fragment; use the origin only.",
    );
  }

  if (!url.hostname) {
    throw new Error("The web origin has no hostname.");
  }

  return { origin: url.origin, hostname: url.hostname };
}

const invokedDirectly =
  process.argv[1] !== undefined &&
  import.meta.url === pathToFileURL(process.argv[1]).href;

if (invokedDirectly) {
  const value = process.argv[2];

  if (!value) {
    console.error("Usage: node scripts/web-origin.ts <web-origin>");
    process.exit(2);
  }

  try {
    const { hostname } = parseWebOrigin(value);
    console.log(hostname);
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
  }
}
