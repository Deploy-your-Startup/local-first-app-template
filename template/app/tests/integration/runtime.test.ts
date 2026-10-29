import assert from "node:assert/strict";
import { test } from "node:test";

import {
  RUNTIME_AVAILABLE_PREFIX,
  describeRuntime,
  isDatabaseDiagnosticsRequest,
  type RuntimeReport,
} from "../../shared/runtime.ts";

const workingRuntime: RuntimeReport = {
  secureContext: true,
  crossOriginIsolated: true,
  serviceWorkerControlled: true,
  webLocks: true,
  opfs: true,
  sqliteVersion: "3.54.1",
};

test("GIVEN every capability WHEN the runtime is described THEN it is all available", () => {
  const description = describeRuntime(workingRuntime);

  assert.equal(description.available, true);
  assert.match(description.text, new RegExp(`^${RUNTIME_AVAILABLE_PREFIX}`));
  assert.match(description.text, /SQLite 3\.54\.1 in OPFS/);
});

test("GIVEN no OPFS WHEN the runtime is described THEN the missing capability is named", () => {
  const description = describeRuntime({ ...workingRuntime, opfs: false });

  assert.equal(description.available, false);
  assert.match(description.text, /missing OPFS/);
  assert.doesNotMatch(description.text, /all available/);
});

test("GIVEN the database worker failed WHEN the runtime is described THEN SQLite is not claimed", () => {
  const description = describeRuntime({
    ...workingRuntime,
    sqliteVersion: null,
  });

  assert.equal(description.available, false);
  assert.match(description.text, /the database worker/);
});

test("GIVEN several missing capabilities WHEN the runtime is described THEN every gap is listed", () => {
  const description = describeRuntime({
    ...workingRuntime,
    secureContext: false,
    crossOriginIsolated: false,
  });

  assert.equal(description.available, false);
  assert.match(description.text, /a secure context/);
  assert.match(description.text, /cross-origin isolation/);
});

test("WHEN database diagnostics messages are checked THEN only the diagnostic envelope passes", () => {
  assert.equal(
    isDatabaseDiagnosticsRequest({ type: "database-diagnostics" }),
    true,
  );
  assert.equal(isDatabaseDiagnosticsRequest({ type: "task-service" }), false);
  assert.equal(isDatabaseDiagnosticsRequest(null), false);
  assert.equal(isDatabaseDiagnosticsRequest("database-diagnostics"), false);
});
