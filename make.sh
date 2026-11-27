#!/usr/bin/env bash
# Template repository checks. The generated project has its own ./make.sh.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$root"

case "${1:-}" in
lint)
    bash -n template/make.sh tests/render_test.sh tests/check_generated.sh
    echo "template scripts are valid bash"
    ;;
test)
    exec bash tests/render_test.sh
    ;;
check)
    exec bash tests/check_generated.sh
    ;;
*)
    echo 'Usage: ./make.sh {lint|test|check}' >&2
    exit 2
    ;;
esac
