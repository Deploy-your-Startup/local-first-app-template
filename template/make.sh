#!/usr/bin/env bash
# Service command contract for this application.
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$project_root"

command="${1:-}"
if [[ $# -gt 0 ]]; then shift; fi

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
    bash -n native/ios/scripts/*.sh
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
    exec bash native/ios/scripts/build.sh
    ;;
test_ios)
    exec bash native/ios/scripts/test.sh
    ;;
check)
    "$project_root/make.sh" lint
    "$project_root/make.sh" test
    "$project_root/make.sh" build
    "$project_root/make.sh" test_e2e
    "$project_root/make.sh" build_ios
    "$project_root/make.sh" test_ios
    ;;
*)
    echo "Usage: $0 {setup_local|run_dev|format|lint|build|test|test_e2e|build_ios|test_ios|check}" >&2
    exit 2
    ;;
esac
