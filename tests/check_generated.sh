#!/usr/bin/env bash
# Render a disposable project, then run its own lint, integration tests,
# production build and browser E2E checks. This is what CI runs.
#
# RENDER_OUTPUT keeps the rendered project at a known path for debugging.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
generated="${RENDER_OUTPUT:-$root/.render-check/generated}"

rm -rf "$generated"
mkdir -p "$(dirname "$generated")"

RENDER_OUTPUT="$generated" bash "$root/tests/render_test.sh"

cd "$generated"

./make.sh setup_local
./make.sh lint
./make.sh test
./make.sh build
./make.sh test_e2e

echo "generated-project checks passed"
