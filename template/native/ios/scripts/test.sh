#!/usr/bin/env bash
# Serve the production build over local HTTPS and run the simulator UI checks.
# The UI test covers: load online, create a task, terminate, make the origin
# unreachable, relaunch and read the saved task from cached UI and OPFS.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_xcode

[ -f "$app_root/dist/index.html" ] ||
  (cd "$project_root" && ./make.sh build)

udid="$(choose_simulator)"
boot_simulator "$udid"
ensure_certificate "$udid"

start_server 8443
trap 'stop_server' EXIT

result_bundle="$native_root/build/TestResults.xcresult"
rm -rf "$result_bundle"
mkdir -p "$native_root/build"

xcodebuild test \
  -project "$native_root/LocalFirstApp.xcodeproj" \
  -scheme LocalFirstApp \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$udid" \
  -derivedDataPath "$native_root/build/DerivedData" \
  -resultBundlePath "$result_bundle" \
  CODE_SIGNING_ALLOWED=NO
