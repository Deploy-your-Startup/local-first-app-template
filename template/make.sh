#!/usr/bin/env bash
# Service command contract for this application.
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$project_root"

# The origin the iOS shell loads by default. `WEB_ORIGIN` overrides it for a
# CDN or a local Cloudflare Tunnel; the allowed hostname is always derived from
# the same value so the WebView configuration cannot drift.
default_web_origin="§§deploy_your_startup.web_origin§§"

command="${1:-}"
if [[ $# -gt 0 ]]; then shift; fi

derived_host() {
  (cd app && node scripts/web-origin.ts "$1")
}

ios_device_family_check() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "iOS checks require macOS with Xcode." >&2
    return 1
  fi
}

build_ios() {
  ios_device_family_check
  local origin="${WEB_ORIGIN:-$default_web_origin}"
  local host
  host="$(derived_host "$origin")"

  (xcrun xcodebuild build \
    -project native/ios/LocalFirstApp.xcodeproj \
    -scheme LocalFirstApp \
    -destination 'generic/platform=iOS Simulator' \
    "WEB_ORIGIN=$origin" \
    "APP_BOUND_DOMAIN=$host" \
    CODE_SIGNING_ALLOWED=NO)
}

case "$command" in
setup_local)
    (cd app && npm ci)
    # CI passes `--with-deps chromium`; local machines only need the browser.
    # shellcheck disable=SC2086
    (cd app && npx playwright install ${PLAYWRIGHT_INSTALL_ARGS:-chromium})
    ;;
run_dev)
    (cd app && exec npm run dev -- "$@")
    ;;
format)
    (cd app && npm run format)
    ;;
lint)
    (cd app && npm run format:check)
    (cd app && npm run lint)
    (cd app && npx tsc --noEmit)
    (cd app && npx tsc -p tsconfig.worker.json --noEmit)
    (cd app && npx tsc -p tsconfig.node.json --noEmit)
    ;;
build)
    (cd app && npm run build)
    ;;
test)
    (cd app && npm test)
    ;;
test_e2e)
    (cd app && npm run test:e2e)
    ;;
build_ios)
    build_ios
    ;;
test_ios)
    build_ios
    (cd app && npm run build)
    (cd app && exec node scripts/ios-simulator.mjs --test)
    ;;
check)
    "$project_root/make.sh" lint
    "$project_root/make.sh" test
    "$project_root/make.sh" build
    "$project_root/make.sh" test_e2e
    if [[ "$(uname -s)" == "Darwin" ]] && command -v xcodebuild >/dev/null 2>&1; then
        "$project_root/make.sh" build_ios
        "$project_root/make.sh" test_ios
    else
        echo "skip native iOS checks: macOS with Xcode is required" >&2
    fi
    ;;
*)
    echo "Usage: $0 {setup_local|run_dev|format|lint|build|test|test_e2e|build_ios|test_ios|check}" >&2
    exit 2
    ;;
esac
