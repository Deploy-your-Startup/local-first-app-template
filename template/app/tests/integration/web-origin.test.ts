import assert from "node:assert/strict";
import { test } from "node:test";

import { parseWebOrigin } from "../../scripts/web-origin.ts";

test("GIVEN an https origin WHEN parsed THEN its origin and bare hostname are returned", () => {
  const { origin, hostname } = parseWebOrigin("https://tasks.example.com");

  assert.equal(origin, "https://tasks.example.com");
  assert.equal(hostname, "tasks.example.com");
});

test("GIVEN an https origin with a port WHEN parsed THEN the hostname has no port", () => {
  const { origin, hostname } = parseWebOrigin("https://example.com:8443");

  assert.equal(origin, "https://example.com:8443");
  assert.equal(hostname, "example.com");
});

test("GIVEN a path or query WHEN parsed THEN the origin is rejected", () => {
  assert.throws(() => parseWebOrigin("https://example.com/app"), /path, query/);
  assert.throws(
    () => parseWebOrigin("https://example.com/?debug=1"),
    /path, query/,
  );
});

test("GIVEN plain http on a public host WHEN parsed THEN it is rejected", () => {
  assert.throws(() => parseWebOrigin("http://example.com"), /must use https/);
});

test("GIVEN the local Vite server WHEN parsed THEN plain http on loopback is accepted", () => {
  const { origin, hostname } = parseWebOrigin("http://localhost:4173");

  assert.equal(origin, "http://localhost:4173");
  assert.equal(hostname, "localhost");
});

test("GIVEN an invalid URL WHEN parsed THEN it is rejected", () => {
  assert.throws(() => parseWebOrigin("not a url"), /not a valid URL/);
});
