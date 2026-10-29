#!/usr/bin/env bash
# Render this template from a committed revision and assert that the result is a
# complete, neutral project.
#
# COPIER_REF       revision to render (default: HEAD, i.e. the last commit)
# RENDER_OUTPUT    keep the rendered project at this path instead of a temp dir
# RENDER_PROJECT_NAME  project name used for the render (default: render-check-app)
#
# Rendering uses `--vcs-ref`, so uncommitted template changes are not rendered:
# commit first, then run this check.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ref="${COPIER_REF:-HEAD}"
project_name="${RENDER_PROJECT_NAME:-render-check-app}"
expected_title="Render Check App"

fail() {
  printf 'FAIL %s\n' "$*" >&2
  exit 1
}

command -v copier >/dev/null 2>&1 ||
  fail "copier is required to render this template"

work="$(mktemp -d)"
cleanup() {
  if [ -z "${RENDER_OUTPUT:-}" ]; then
    rm -rf "$work"
  fi
}
trap cleanup EXIT

destination="${RENDER_OUTPUT:-$work/$project_name}"
rm -rf "$destination"
mkdir -p "$(dirname "$destination")"

copier copy --quiet --defaults --vcs-ref "$ref" \
  --data "project_name=$project_name" \
  "$root" "$destination"

generated="$destination"

echo "rendered $project_name from $ref to $generated"

# --- the rendered project is complete ------------------------------------
for file in \
  LICENSE \
  README.md \
  AGENTS.md \
  make.sh \
  mise.toml \
  app/package.json \
  app/package-lock.json \
  app/index.html \
  app/src/main.ts \
  app/src/database.ts \
  app/worker/sw.ts \
  app/worker/database.ts \
  app/worker/services/tasks.ts \
  app/shared/app.ts \
  app/shared/tasks.ts \
  app/tests/integration/tasks.test.ts \
  app/tests/e2e/tasks.spec.ts \
  app/public/sqlite/3.54.1/sqlite3.wasm \
  app/public/sqlite/3.54.1/sqlite3.mjs \
  app/THIRD-PARTY-NOTICES.md \
  native/ios/LocalFirstApp.xcodeproj/project.pbxproj \
  native/ios/LocalFirstApp/AppDelegate.swift \
  native/ios/LocalFirstApp/SceneDelegate.swift \
  native/ios/LocalFirstApp/Info.plist \
  native/ios/LocalFirstAppUITests/LocalFirstAppUITests.swift \
  native/ios/scripts/build.sh \
  native/ios/scripts/test.sh \
  docs/architecture/001-local-web-runtime.md \
  docs/architecture/002-ios-webview-runtime.md; do
  [ -s "$generated/$file" ] || fail "generated project is missing $file"
done

[ -x "$generated/make.sh" ] || fail "generated make.sh is not executable"
[ ! -e "$generated/.git" ] || fail "generated project contains template git metadata"
if [ -e "$generated/app/node_modules" ]; then
  fail "generated project contains node_modules"
fi
if [ -e "$generated/app/dist" ]; then
  fail "generated project contains a build output"
fi
if [ -e "$generated/app/.local-https" ]; then
  fail "generated project contains local development certificates"
fi
if [ -e "$generated/native/ios/build" ]; then
  fail "generated project contains native build output"
fi
bash -n "$generated/make.sh" || fail "generated make.sh is not valid bash"

cmp -s "$root/template/app/public/sqlite/3.54.1/sqlite3.wasm" \
  "$generated/app/public/sqlite/3.54.1/sqlite3.wasm" ||
  fail "the SQLite WASM binary was altered during rendering"
cmp -s "$root/template/app/public/sqlite/3.54.1/sqlite3.mjs" \
  "$generated/app/public/sqlite/3.54.1/sqlite3.mjs" ||
  fail "the SQLite module was altered during rendering"

pass() { printf 'ok   %s\n' "$*"; }
pass "rendered project contains the application, checks, notices and SQLite runtime"

# --- no unresolved placeholders ------------------------------------------
if grep -rIl -- "§§" "$generated" >/dev/null 2>&1; then
  grep -rIl -- "§§" "$generated" >&2
  fail "generated project contains unresolved template placeholders"
fi
pass "no unresolved placeholders"

# --- the answers reached the code ----------------------------------------
grep -qF "\"$project_name\"" "$generated/app/shared/app.ts" ||
  fail "project_name was not rendered into app/shared/app.ts"
grep -qF "$expected_title" "$generated/app/index.html" ||
  fail "the app_title default was not rendered into app/index.html"
grep -qF "MIT License" "$generated/LICENSE" ||
  fail "the generated project does not carry the MIT license"
pass "project_name and the derived app_title are rendered"

# --- iOS shell identity and origin ---------------------------------------
grep -qF "com.example.$project_name" \
  "$generated/native/ios/LocalFirstApp.xcodeproj/project.pbxproj" ||
  fail "the iOS bundle identifier was not rendered from project_name"
grep -qF "<string>$expected_title</string>" "$generated/native/ios/LocalFirstApp/Info.plist" ||
  fail "the iOS display name was not rendered from app_title"
grep -qF "<string>https://localhost:8443</string>" \
  "$generated/native/ios/LocalFirstApp/Info.plist" ||
  fail "the default web origin was not rendered into the iOS shell"
pass "iOS shell carries the rendered display name, bundle identifier and origin"

# --- neutral content ------------------------------------------------------
# The template must not leak the source application, owner infrastructure or
# machine settings into generated projects.
for pattern in \
  "malleable" \
  "Malleable Mail" \
  "GreenMail" \
  "nodemailer" \
  "ts.net" \
  "macbook-pro"; do
  if grep -rIil -- "$pattern" "$generated" >/dev/null 2>&1; then
    fail "generated project contains source-specific content: $pattern"
  fi
done
if grep -rIE -- '/Users/[A-Za-z0-9._-]+' "$generated" >/dev/null 2>&1; then
  fail "generated project contains an absolute personal machine path"
fi
pass "no source branding, private hosts or personal machine paths"

# --- the rendered project declares the service commands it needs ---------
node -e '
const { readFileSync } = require("node:fs");
const pkg = JSON.parse(readFileSync(process.argv[1], "utf8"));
const required = ["dev", "build", "format", "format:check", "lint", "test", "test:e2e"];
const missing = required.filter((script) => !pkg.scripts?.[script]);
if (missing.length > 0) {
  console.error(`app/package.json is missing scripts: ${missing.join(", ")}`);
  process.exit(1);
}
' "$generated/app/package.json" || fail "rendered package.json lacks required scripts"
pass "rendered app declares dev/build/format/lint/test scripts"

echo "render check passed"
