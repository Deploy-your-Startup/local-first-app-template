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
  app/shared/runtime.ts \
  app/scripts/web-origin.ts \
  app/scripts/ios-simulator.mjs \
  app/tests/integration/tasks.test.ts \
  app/tests/integration/runtime.test.ts \
  app/tests/integration/web-origin.test.ts \
  app/tests/e2e/tasks.spec.ts \
  app/public/sqlite/3.54.1/sqlite3.wasm \
  app/public/sqlite/3.54.1/sqlite3.mjs \
  app/THIRD-PARTY-NOTICES.md \
  native/ios/LocalFirstApp.xcodeproj/project.pbxproj \
  native/ios/LocalFirstApp.xcodeproj/xcshareddata/xcschemes/LocalFirstApp.xcscheme \
  native/ios/LocalFirstApp/Info.plist \
  native/ios/LocalFirstApp/AppDelegate.swift \
  native/ios/LocalFirstApp/SceneDelegate.swift \
  native/ios/LocalFirstApp/AppWebViewController.swift \
  native/ios/LocalFirstApp/AboutViewController.swift \
  native/ios/LocalFirstAppUITests/OnlineFlowTests.swift \
  native/ios/LocalFirstAppUITests/OfflineRelaunchTests.swift \
  docs/architecture/001-local-web-runtime.md \
  docs/architecture/002-ios-wkwebview-loading.md; do
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
if [ -e "$generated/app/.local-ios" ]; then
  fail "generated project contains transient simulator state"
fi
bash -n "$generated/make.sh" || fail "generated make.sh is not valid bash"

cmp -s "$root/template/app/public/sqlite/3.54.1/sqlite3.wasm" \
  "$generated/app/public/sqlite/3.54.1/sqlite3.wasm" ||
  fail "the SQLite WASM binary was altered during rendering"
cmp -s "$root/template/app/public/sqlite/3.54.1/sqlite3.mjs" \
  "$generated/app/public/sqlite/3.54.1/sqlite3.mjs" ||
  fail "the SQLite module was altered during rendering"

pass() { printf 'ok   %s\n' "$*"; }
pass "rendered project contains the application, iOS shell, checks, notices and SQLite runtime"

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
grep -qF "<string>$expected_title</string>" "$generated/native/ios/LocalFirstApp/Info.plist" ||
  fail "ios_display_name was not rendered into Info.plist"
grep -qF "com.example.$project_name" "$generated/native/ios/LocalFirstApp.xcodeproj/project.pbxproj" ||
  fail "ios_bundle_identifier was not rendered into the Xcode project"
grep -qF "MIT License" "$generated/LICENSE" ||
  fail "the generated project does not carry the MIT license"
pass "project_name, app_title, ios_display_name and ios_bundle_identifier are rendered"

# --- the WebView origin and app-bound domain share one source ------------
INFO_PLIST="$generated/native/ios/LocalFirstApp/Info.plist"
PROJECT_PBX="$generated/native/ios/LocalFirstApp.xcodeproj/project.pbxproj"
APP_DELEGATE="$generated/native/ios/LocalFirstApp/AppDelegate.swift"

grep -qF "<string>\$(WEB_ORIGIN)</string>" "$INFO_PLIST" ||
  fail "Info.plist must expand HotwireRootURL from WEB_ORIGIN"
grep -qF "<string>\$(APP_BOUND_DOMAIN)</string>" "$INFO_PLIST" ||
  fail "Info.plist must expand WKAppBoundDomains from APP_BOUND_DOMAIN"
grep -qF "limitsNavigationsToAppBoundDomains" "$APP_DELEGATE" ||
  fail "the shell does not enable limitsNavigationsToAppBoundDomains"
grep -qE 'WEB_ORIGIN = "http://localhost:4173";' "$PROJECT_PBX" ||
  fail "the project does not default WEB_ORIGIN to the local preview origin"
grep -qE 'APP_BOUND_DOMAIN = "localhost";' "$PROJECT_PBX" ||
  fail "the project does not derive the default app-bound domain"
pass "the shell loads WEB_ORIGIN and restricts WKAppBoundDomains to its hostname"

# A changed origin must change the allowed hostname, not just the URL.
custom="$(mktemp -d)"
copier copy --quiet --defaults --vcs-ref "$ref" \
  --data "project_name=$project_name" \
  --data "web_origin=https://tasks.example.test" \
  "$root" "$custom/project"
grep -qF 'APP_BOUND_DOMAIN = "tasks.example.test";' \
  "$custom/project/native/ios/LocalFirstApp.xcodeproj/project.pbxproj" ||
  fail "app_bound_domain did not follow a custom web_origin"
grep -qF 'WEB_ORIGIN = "https://tasks.example.test";' \
  "$custom/project/native/ios/LocalFirstApp.xcodeproj/project.pbxproj" ||
  fail "a custom web_origin was not rendered into the project"
rm -rf "$custom"
pass "a custom web_origin moves the app-bound domain with it"

# --- transient remote state is never committed ---------------------------
if grep -rIE -- 'https://[a-z0-9-]+\.trycloudflare\.com' "$generated" >/dev/null 2>&1; then
  fail "generated project contains a transient tunnel URL"
fi
pass "no transient tunnel URL is committed"

# --- neutral content ------------------------------------------------------
# The template must not leak the source application, owner infrastructure or
# machine settings into generated projects.
for pattern in \
  "malleable" \
  "MalleableMail" \
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
pass "no source branding, private hosts, personal machine paths or signing teams"

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
grep -qE '^build_ios\)' "$generated/make.sh" ||
  fail "the generated make.sh lacks build_ios"
grep -qE '^test_ios\)' "$generated/make.sh" ||
  fail "the generated make.sh lacks test_ios"
pass "rendered app declares dev/build/format/lint/test scripts and native commands"

echo "render check passed"
