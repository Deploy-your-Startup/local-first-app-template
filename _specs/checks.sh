#!/usr/bin/env bash
# Checks for the active vertical slice (see _specs/todo.md).
#
# Slice 0 asserted the extraction boundary against the source application.
# Slice 1 added a Copier template; this file renders a disposable project from
# the template's committed revision and runs that project's real lint,
# integration, build and Chrome E2E checks. Slice 2 was rolled back; native,
# HTTPS-origin and offline checks are not part of the active baseline.
# Every check below is bound to a real
# command in an explicit repository path; nothing is a placeholder.
set -euo pipefail

specs_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${TEMPLATE_ROOT:-$(cd "$specs_root/.." && pwd)}"
factory_root="${FACTORY_ROOT:-$(cd "$TEMPLATE/../../.." && pwd)}"
cd "$specs_root/.."

SOURCE="$factory_root/projects/startups/malleable-mail/app-src"
APP="$SOURCE/app"
MAP="$specs_root/extraction-map.md"
TODO="$specs_root/todo.md"
SCRATCH="$specs_root/scratchpad.md"

pass() { printf 'ok   %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

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
have copier || fail "copier is required to render the template"
"$TEMPLATE/make.sh" lint
"$TEMPLATE/make.sh" test
pass "template renders a complete, neutral project"

# --- the rendered project really works -----------------------------------
# `make.sh check` renders again, installs dependencies, and runs the generated
# project's lint, integration tests, static build and Chrome E2E checks.
# It lives in .render-check/generated.
have node || fail "node is required to check the generated project"
"$TEMPLATE/make.sh" check
pass "generated project passes lint, integration, build and Chrome E2E checks"

# --- no certificates, build output or personal paths are committed ------
for leaked in \
  "$TEMPLATE/.render-check"; do
  if git -C "$TEMPLATE" ls-files --error-unmatch "${leaked#"$TEMPLATE/"}" >/dev/null 2>&1; then
    fail "generated/development output is committed: ${leaked#"$TEMPLATE/"}"
  fi
done
if git -C "$TEMPLATE" grep -qE '/Users/[A-Za-z0-9._-]+' -- template; then
  fail "template sources contain an absolute personal machine path"
fi
if git -C "$TEMPLATE" grep -qiE '(BEGIN (RSA )?PRIVATE KEY|DEVELOPMENT_TEAM)' -- template; then
  fail "template sources contain a private key or signing team"
fi
pass "no certificates, build output, personal paths or signing identities are committed"

# --- CI scope ------------------------------------------------------------
grep -qF "test_e2e" "$WORKFLOW" ||
  fail "CI no longer runs the generated browser checks"
pass "CI keeps the Linux browser suite"

echo
cat <<'EOF'
skip iOS/native            — slice 2 was rolled back; simulator and device
                             behavior are not proven in this baseline
skip Safari/Firefox        — Chrome is the only claimed browser
skip CDN/HTTPS hosting     — hosting and an HTTPS test origin are not implemented
skip offline reopening    — deferred to slices 2 and 6
skip Rust bridge checks    — the "hello from rust" bridge is slice 3
skip multi-tab state tests — the explicit "already open in another tab" UI is
                             slice 6; the single-owner lock is already enforced
EOF

echo
echo "== slice 1 checks passed =="
