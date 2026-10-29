/**
 * Runtime facts the page can observe about itself and about the database
 * worker. They are rendered as a visible status line so the browser and the
 * native WebView check the same capabilities instead of assuming them.
 */
export interface PageRuntimeFacts {
  secureContext: boolean;
  crossOriginIsolated: boolean;
  serviceWorkerControlled: boolean;
  webLocks: boolean;
  opfs: boolean;
}

/** Message the database worker answers with the SQLite version it opened. */
export interface DatabaseDiagnosticsRequest {
  type: "database-diagnostics";
}

export type DatabaseDiagnosticsResponse =
  | { type: "database-diagnostics"; sqliteVersion: string }
  | { type: "database-diagnostics"; error: string };

export interface RuntimeReport extends PageRuntimeFacts {
  sqliteVersion: string | null;
}

export interface RuntimeDescription {
  available: boolean;
  text: string;
}

export const RUNTIME_AVAILABLE_PREFIX = "Runtime: all available";

export function isDatabaseDiagnosticsRequest(
  value: unknown,
): value is DatabaseDiagnosticsRequest {
  return (
    typeof value === "object" &&
    value !== null &&
    (value as { type?: unknown }).type === "database-diagnostics"
  );
}

/**
 * Lists exactly what is missing instead of claiming a working runtime. Every
 * capability here is required for durable local task storage.
 */
export function describeRuntime(report: RuntimeReport): RuntimeDescription {
  const checks: Array<[string, boolean]> = [
    ["a secure context", report.secureContext],
    ["cross-origin isolation", report.crossOriginIsolated],
    ["a service worker", report.serviceWorkerControlled],
    ["Web Locks", report.webLocks],
    ["OPFS", report.opfs],
    ["the database worker", report.sqliteVersion !== null],
  ];
  const missing = checks
    .filter(([, available]) => !available)
    .map(([name]) => name);

  if (missing.length === 0) {
    return {
      available: true,
      text: `${RUNTIME_AVAILABLE_PREFIX} (SQLite ${report.sqliteVersion} in OPFS)`,
    };
  }

  return {
    available: false,
    text: `Runtime degraded: missing ${missing.join(", ")}.`,
  };
}
