#!/usr/bin/env bash
# Build the generated Hotwire Native shell for the iOS simulator.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_xcode

xcodebuild \
  -project "$native_root/LocalFirstApp.xcodeproj" \
  -scheme LocalFirstApp \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$native_root/build/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  build
