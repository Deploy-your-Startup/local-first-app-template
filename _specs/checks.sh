#!/usr/bin/env bash
# Checks for the active vertical slice (see _specs/todo.md).
#
# Slice 0 asserted the extraction boundary against the source application.
# Slice 1 added a Copier template that renders a Chrome application saving one
# local task. Slice 2 adds the iOS WKWebView shell: the rendered project's
# simulator UI flow loads the web runtime through a Cloudflare Tunnel, saves a
# task, and reopens it after the origin is made unreachable.
#
# Every check below is bound to a real command in an explicit repository path;
# nothing is a placeholder. CHECKS_FAST=1 runs the structural assertions only
# (used by _specs/checks.test.mjs); a completed slice still requires the full
# run, including the rendered project, Chrome E2E and the iOS simulator flow.
set -euo pipefail

specs_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script_path="$specs_root/$(basename "${BASH_SOURCE[0]}")"
TEMPLATE="${TEMPLATE_ROOT:-$(cd "$specs_root/.." && pwd)}"
factory_root="${FACTORY_ROOT:-$(cd "$TEMPLATE/../../.." && pwd)}"

SOURCE="$factory_root/projects/startups/malleable-mail/app-src"
APP="$SOURCE/app"
MAP="$specs_root/extraction-map.md"
TODO="$specs_root/todo.md"
SCRATCH="$specs_root/scratchpad.md"

pass() { printf 'ok   %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# --- prerequisites --------------------------------------------------------
# The gate runs the real native flow, so it needs a full Xcode and cloudflared.
# Resolve them here instead of relying on the caller's shell, which may select
# the Command Line Tools or lack cloudflared. Nothing is skipped: if the tools
# cannot be resolved the run fails with an actionable message.
if [ "${CHECKS_FAST:-0}" != "1" ]; then
  if ! have cloudflared && have nix && [ -z "${CHECKS_REEXEC:-}" ]; then
    export CHECKS_REEXEC=1
    exec nix shell nixpkgs#cloudflared -c bash "$script_path" "$@"
  fi

  # `xcode-select` may point at the Command Line Tools, where xcodebuild and
  # simctl are unavailable. Pick an installed Xcode without hardcoding a
  # version or a personal path.
  if [ "$(uname -s)" = "Darwin" ] && ! xcodebuild -version >/dev/null 2>&1; then
    for candidate in /Applications/Xcode*.app/Contents/Developer; do
      [ -d "$candidate" ] || continue
      if DEVELOPER_DIR="$candidate" xcodebuild -version >/dev/null 2>&1; then
        export DEVELOPER_DIR="$candidate"
        break
      fi
    done
  fi
fi

cd "$specs_root/.."

echo "== slice 0: extraction boundary =="

# --- artifacts ------------------------------------------------------------
for file in "$MAP" "$TODO" "$SCRATCH"; do
  [ -s "$file" ] || fail "missing or empty: ${file#"$factory_root"/}"
done
pass "slice artifacts exist (extraction map, todo, scratchpad)"

# --- extraction map completeness -----------------------------------------
# Each heading is a required part of the recorded extraction.
for heading in \
  "## 1. Approvals" \
  "## 3. Browser path" \
  "## 4. iOS path" \
  "## 5. Rust scope" \
  "## 6. Keep out of the template" \
  "## 7. Licensing" \
  "## 8. Compatibility risks"
do
  grep -qF "$heading" "$MAP" || fail "extraction map is missing section: $heading"
done
pass "extraction map records approvals, both platform paths, Rust scope, exclusions, licensing, risks"

# Approvals were explicitly resolved in the owner clarification session.
grep -qF "A1–A9 are resolved" "$MAP" ||
  fail "extraction map does not record the resolved owner decisions"
if grep -qF 'pending owner' "$MAP"; then
  fail "extraction map still contains obsolete pending owner decisions"
fi
for decision in A1 A2 A3 A4 A5 A6 A7 A8 A9; do
  grep -qF "| $decision |" "$MAP" || fail "missing owner decision: $decision"
done
pass "owner decisions A1–A9 are recorded as resolved"

[ -d "$TEMPLATE/.git" ] || fail "template repository is missing its own .git directory"
[ "$(git -C "$TEMPLATE" remote get-url origin)" = \
  'git@github.com:Deploy-your-Startup/local-first-app-template.git' ] ||
  fail "template repository origin differs from the approved remote"
git -C "$TEMPLATE" rev-parse --verify origin/main >/dev/null ||
  fail "template repository has no fetched origin/main baseline"
grep -qF 'MIT License' "$TEMPLATE/LICENSE" || fail "template repository MIT license missing"
pass "independent template repository, approved origin, fetched main and MIT license verified"

# --- documented traces match the source ----------------------------------
[ -f "$APP/worker/sw.ts" ] || fail "source moved: app/worker/sw.ts is missing"
[ -f "$APP/worker/database.ts" ] || fail "source moved: app/worker/database.ts is missing"
[ -f "$APP/src/database.ts" ] || fail "source moved: app/src/database.ts is missing"

grep -qF 'basePath("/local")' "$APP/worker/sw.ts" ||
  fail "browser trace drift: worker/sw.ts no longer mounts the Hono app at /local"
pass "browser trace: Hono is mounted at /local in the service worker"

grep -qF "installOpfsSAHPoolVfs" "$APP/worker/database.ts" ||
  fail "browser trace drift: the database worker no longer uses the OPFS SAH pool"
grep -qF "drizzle" "$APP/worker/database.ts" ||
  fail "browser trace drift: the database worker no longer wraps Drizzle"
pass "browser trace: database worker uses SQLite WASM OPFS SAH pool via Drizzle"

# The recorded gap: the DB client is defined but never wired into the page.
if grep -rn --include='*.ts' -e 'from "\./database"' -e "from '\./database'" \
     "$APP/src" >/dev/null 2>&1; then
  fail "browser trace drift: src/database.ts is now imported, the gap in the map is stale"
fi
pass "browser trace: src/database.ts is still unwired in the source (documented gap holds)"

# The SDK-independent iOS facts: remote root URL, app-bound domain, no Rust DB.
grep -qE 'startLocation: rootURL' "$SOURCE/ios/MalleableMail/MalleableMail/SceneDelegate.swift" ||
  fail "iOS trace drift: the Hotwire navigator no longer starts from a configured root URL"
grep -qE 'URL\(string: "https://' "$SOURCE/ios/MalleableMail/MalleableMail/SceneDelegate.swift" ||
  fail "iOS trace drift: the navigator no longer loads remote https content"
pass "iOS trace: shell loads remote https content (approved content model)"

grep -qF "WKAppBoundDomains" "$SOURCE/ios/MalleableMail/MalleableMail/Info.plist" ||
  fail "iOS trace drift: app-bound domains are no longer configured"
pass "iOS trace: app-bound domains still restrict the WebView"

grep -qF "uniffi" "$SOURCE/rustsrc/crates/mail-core/Cargo.toml" ||
  fail "Rust trace drift: mail-core no longer exposes UniFFI"
if grep -qiE '^[[:space:]]*(rusqlite|libsqlite3-sys|sqlx|diesel)[[:space:]]*=' \
     "$SOURCE/rustsrc/crates/mail-core/Cargo.toml"; then
  fail "Rust trace drift: mail-core now has SQLite; update the source inventory"
fi
pass "Rust trace: UniFFI present, no SQLite dependency (native persistence is out of scope)"

[ -x "$SOURCE/make.sh" ] || fail "service command contract missing: $SOURCE/make.sh is not executable"
for command in setup_local run_dev format lint test; do
  grep -qE "^[[:space:]]*${command}\)" "$SOURCE/make.sh" ||
    fail "service command contract drift: make.sh no longer implements '$command'"
done
pass "service command contract: make.sh still implements setup_local/run_dev/format/lint/test"

# --- no owner data leaks into the recorded material ----------------------
# The map documents owner identifiers by description; it must never contain them.
for file in "$MAP" "$SCRATCH" "$specs_root/pr/slice-0.md"; do
  [ -f "$file" ] || fail "missing: ${file#"$factory_root"/}"
  name="${file#"$factory_root"/}"
  if grep -qE '\.ts\.net' "$file"; then
    fail "$name contains a private tailnet host"
  fi
  if grep -qE '/Users/[A-Za-z0-9._-]+' "$file"; then
    fail "$name contains an absolute personal machine path"
  fi
done
pass "no private hosts or personal machine paths in the recorded material"

# --- loop harness --------------------------------------------------------
[ -f "$specs_root/run-loop.sh" ] || fail "missing: _specs/run-loop.sh"
[ -f "$specs_root/run-loop.test.mjs" ] || fail "missing: _specs/run-loop.test.mjs"
have node || fail "node is required to run the loop harness tests"
node --test "$specs_root/run-loop.test.mjs" >/dev/null ||
  fail "the slice loop harness tests failed (_specs/run-loop.test.mjs)"
pass "slice loop harness tests pass"

echo
echo "== slice 1: generated Chrome app saves one task locally =="

# --- the template exists and is committed --------------------------------
[ -s "$TEMPLATE/copier.yml" ] || fail "missing: copier.yml in the template repository"
for file in \
  "$TEMPLATE/template/app/package.json" \
  "$TEMPLATE/template/app/package-lock.json" \
  "$TEMPLATE/template/app/index.html" \
  "$TEMPLATE/template/make.sh" \
  "$TEMPLATE/template/mise.toml" \
  "$TEMPLATE/tests/render_test.sh" \
  "$TEMPLATE/tests/check_generated.sh"; do
  [ -s "$file" ] || fail "missing template file: ${file#"$TEMPLATE"/}"
done
pass "template, generated-project skeleton, service commands and render checks exist"

# Rendering tests the committed revision, so a dirty template tree would
# validate something other than what will be pushed.
if [ -n "$(git -C "$TEMPLATE" status --porcelain)" ]; then
  git -C "$TEMPLATE" status --porcelain >&2
  fail "template repository has uncommitted changes; commit before rendering"
fi
pass "template repository is committed (render checks test the pushed revision)"

# The Copier contract: parameterised answers and no deployment assumptions.
grep -qF "_min_copier_version" "$TEMPLATE/copier.yml" ||
  fail "copier.yml does not pin a minimum Copier version"
for variable in project_name app_title; do
  grep -qE "^${variable}:" "$TEMPLATE/copier.yml" ||
    fail "copier.yml does not declare the '$variable' answer"
done
grep -qF "**/node_modules" "$TEMPLATE/copier.yml" ||
  fail "copier.yml does not exclude node_modules from rendering"
pass "copier.yml declares project_name/app_title and excludes build inputs"

# --- the CI entrypoint runs the same checks ------------------------------
WORKFLOW="$TEMPLATE/.github/workflows/template-check.yml"
[ -s "$WORKFLOW" ] || fail "missing CI entrypoint: .github/workflows/template-check.yml"
for step in "tests/render_test.sh" "./make.sh lint" "./make.sh test" "./make.sh build" "./make.sh test_e2e"; do
  grep -qF "$step" "$WORKFLOW" ||
    fail "CI entrypoint does not run: $step"
done
pass "CI renders a project and runs the same lint/integration/build/E2E commands"

# --- shell scripts parse -------------------------------------------------
bash -n "$TEMPLATE/make.sh" "$TEMPLATE/template/make.sh" \
  "$TEMPLATE/tests/render_test.sh" "$TEMPLATE/tests/check_generated.sh"
pass "template shell scripts are valid bash"

# --- rendering -----------------------------------------------------------
if [ "${CHECKS_FAST:-0}" = "1" ]; then
  echo "CHECKS_FAST: skipping rendering and the generated-project checks"
else
  have copier || fail "copier is required to render the template"
  "$TEMPLATE/make.sh" lint
  "$TEMPLATE/make.sh" test
  pass "template renders a complete, neutral project"

  # --- the rendered project really works ---------------------------------
  # `make.sh check` renders again, installs dependencies, and runs the generated
  # project's lint, integration tests, static build and Chrome E2E checks.
  # It lives in .render-check/generated.
  have node || fail "node is required to check the generated project"
  "$TEMPLATE/make.sh" check
  pass "generated project passes lint, integration, build and Chrome E2E checks"
fi

echo
echo "== slice 2: save and reopen one task in iOS WKWebView =="

# --- the native shell is part of the template -----------------------------
IOS="$TEMPLATE/template/native/ios"
for file in \
  "$IOS/LocalFirstApp.xcodeproj/project.pbxproj" \
  "$IOS/LocalFirstApp.xcodeproj/xcshareddata/xcschemes/LocalFirstApp.xcscheme" \
  "$IOS/LocalFirstApp/Info.plist" \
  "$IOS/LocalFirstApp/AppDelegate.swift" \
  "$IOS/LocalFirstApp/SceneDelegate.swift" \
  "$IOS/LocalFirstApp/AppWebViewController.swift" \
  "$IOS/LocalFirstApp/AboutViewController.swift" \
  "$IOS/LocalFirstAppUITests/OnlineFlowTests.swift" \
  "$IOS/LocalFirstAppUITests/OfflineRelaunchTests.swift" \
  "$TEMPLATE/template/app/scripts/ios-simulator.mjs" \
  "$TEMPLATE/template/app/scripts/web-origin.ts" \
  "$TEMPLATE/template/docs/architecture/002-ios-wkwebview-loading.md"; do
  [ -s "$file" ] || fail "missing native file: ${file#"$TEMPLATE"/}"
done
pass "Hotwire Native shell, simulator UI tests, harness and ADR 002 exist"

# --- origin and app-bound domain stay aligned -----------------------------
for variable in ios_display_name ios_bundle_identifier web_origin app_bound_domain; do
  grep -qE "^${variable}:" "$TEMPLATE/copier.yml" ||
    fail "copier.yml does not declare the '$variable' answer"
done
grep -qF '<string>$(WEB_ORIGIN)</string>' "$IOS/LocalFirstApp/Info.plist" ||
  fail "Info.plist no longer loads the root URL from WEB_ORIGIN"
grep -qF '<string>$(APP_BOUND_DOMAIN)</string>' "$IOS/LocalFirstApp/Info.plist" ||
  fail "Info.plist no longer expands WKAppBoundDomains from APP_BOUND_DOMAIN"
grep -qF "limitsNavigationsToAppBoundDomains = true" "$IOS/LocalFirstApp/AppDelegate.swift" ||
  fail "the shell no longer enables limitsNavigationsToAppBoundDomains"
grep -qF "WKAppBoundDomains" "$IOS/LocalFirstApp/SceneDelegate.swift" ||
  fail "the shell no longer validates the app-bound domain against the origin"
grep -qF 'APP_BOUND_DOMAIN = "§§deploy_your_startup.app_bound_domain§§";' \
  "$IOS/LocalFirstApp.xcodeproj/project.pbxproj" ||
  fail "the Xcode project no longer derives the app-bound domain from the answers"
pass "the shell derives WEB_ORIGIN and WKAppBoundDomains from one configuration"

# --- the simulator flow is real, not a placeholder ------------------------
HARNESS="$TEMPLATE/template/app/scripts/ios-simulator.mjs"
grep -qF "cloudflared" "$HARNESS" ||
  fail "the simulator harness no longer uses a Cloudflare Tunnel"
grep -qF "trycloudflare" "$HARNESS" ||
  fail "the simulator harness no longer parses the tunnel hostname"
grep -qF "originReachable" "$HARNESS" ||
  fail "the simulator harness no longer verifies the origin state"
grep -qF "OnlineFlowTests" "$HARNESS" ||
  fail "the simulator harness no longer runs the online UI flow"
grep -qF "OfflineRelaunchTests" "$HARNESS" ||
  fail "the simulator harness no longer runs the offline relaunch"
grep -qF "Runtime: all available" "$IOS/LocalFirstAppUITests/OnlineFlowTests.swift" ||
  fail "the online UI flow no longer checks the WKWebView runtime status"
grep -qF "SQLite 3.54.1 in OPFS" "$IOS/LocalFirstAppUITests/OnlineFlowTests.swift" ||
  fail "the online UI flow no longer checks the SQLite runtime in OPFS"
grep -qF 'Buy oat milk' "$IOS/LocalFirstAppUITests/OfflineRelaunchTests.swift" ||
  fail "the offline relaunch no longer asserts the saved task"
grep -qF "No tasks yet." "$IOS/LocalFirstAppUITests/OfflineRelaunchTests.swift" ||
  fail "the offline relaunch no longer rejects an empty database"
pass "the simulator tests assert the real runtime, the saved task and the offline relaunch"

# --- no transient remote state in the template ----------------------------
if git -C "$TEMPLATE" grep -qE 'https://[a-z0-9-]+\.trycloudflare\.com' -- template; then
  fail "the template contains a transient Cloudflare tunnel URL"
fi
if git -C "$TEMPLATE" grep -qiE '(BEGIN (RSA )?PRIVATE KEY|DEVELOPMENT_TEAM = [A-Z0-9])' \
     -- template/native; then
  fail "the native template contains a private key or signing team"
fi
if git -C "$TEMPLATE" grep -qE '/Users/[A-Za-z0-9._-]+' -- template; then
  fail "template sources contain an absolute personal machine path"
fi
pass "no tunnel URLs, certificates, signing teams or personal paths in the template"

# --- the generated project exposes the native commands --------------------
grep -qE '^build_ios\)' "$TEMPLATE/template/make.sh" ||
  fail "the generated make.sh does not implement build_ios"
grep -qE '^test_ios\)' "$TEMPLATE/template/make.sh" ||
  fail "the generated make.sh does not implement test_ios"
if grep -qF './make.sh build_ios' "$WORKFLOW"; then
  fail "CI must not run native checks on Linux"
fi
pass "the generated project exposes build_ios/test_ios; CI stays browser-only"

# --- run the native checks (macOS, Xcode, simulator, tunnel) --------------
if [ "${CHECKS_FAST:-0}" = "1" ]; then
  echo "CHECKS_FAST: skipping the iOS simulator and Chrome execution checks"
else
  [ "$(uname -s)" = "Darwin" ] ||
    fail "slice 2 requires macOS with Xcode to run the simulator checks"
  have xcrun || fail "xcrun is required for the iOS simulator checks"
  have xcodebuild || fail "xcodebuild is required for the iOS simulator checks"
  xcodebuild -version >/dev/null 2>&1 ||
    fail "xcodebuild cannot run; install Xcode and select it with xcode-select or DEVELOPER_DIR (the Command Line Tools are not enough)"
  have cloudflared ||
    fail "cloudflared is required to serve the simulator origin over HTTPS (install it, or provide nix so the gate can supply it)"
  xcrun simctl list runtimes 2>/dev/null | grep -q "iOS" ||
    fail "no iOS simulator runtime is installed"

  GENERATED="$TEMPLATE/.render-check/generated"
  [ -x "$GENERATED/make.sh" ] ||
    fail "missing rendered project; run the full checks to render it first"
  (cd "$GENERATED" && ./make.sh build_ios)
  pass "generated iOS shell builds for the simulator"
  (cd "$GENERATED" && ./make.sh test_ios)
  pass "generated iOS shell saves a task and reopens it after the origin is unreachable"
fi

echo
cat <<'EOF'
skip physical iOS device  — the simulator is the tested target; signing and
                            devices are out of scope
skip real CDN deployment  — the HTTPS origin is a local Cloudflare Tunnel, not
                            production hosting
skip Chrome offline flow  — cached restart in Chrome is covered in slice 6; the
                            iOS relaunch is proven here
skip Safari/Firefox       — Chrome is the only claimed browser
skip Rust bridge checks   — the "hello from rust" bridge is slice 3
skip multi-tab state tests — the explicit "already open in another tab" UI is
                            slice 6; the single-owner lock is already enforced
EOF

echo
echo "== slice 2 checks passed =="
