#!/usr/bin/env bash
# Render a disposable project, then run its own lint, integration tests,
# production build, browser E2E and iOS simulator checks. This is what a
# complete local check runs; CI runs the non-native subset because it has no
# Xcode/simulator.
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
./make.sh build_ios
./make.sh test_ios

echo "generated-project checks passed"
