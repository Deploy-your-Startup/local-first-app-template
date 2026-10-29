#!/usr/bin/env bash
# Shared helpers for the iOS simulator checks. Xcode must be selected, or
# DEVELOPER_DIR must point at an Xcode installation. No machine-specific path
# is assumed.
set -euo pipefail

native_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_root="$(cd "$native_root/../.." && pwd)"
app_root="$project_root/app"

fail() {
  printf 'FAIL %s\n' "$*" >&2
  exit 1
}

require_xcode() {
  command -v xcodebuild >/dev/null 2>&1 ||
    fail "xcodebuild is unavailable. Install Xcode and select it with 'xcode-select -s <path>' or set DEVELOPER_DIR."
  command -v xcrun >/dev/null 2>&1 ||
    fail "xcrun is unavailable. Install Xcode and select it with 'xcode-select -s <path>' or set DEVELOPER_DIR."
  xcodebuild -version >/dev/null 2>&1 ||
    fail "xcodebuild cannot run. Select a full Xcode installation, not Command Line Tools."
  xcrun simctl list runtimes 2>/dev/null | grep -q 'iOS' ||
    fail "No iOS simulator runtime is installed."
}

choose_simulator() {
  if [ -n "${IOS_SIMULATOR_UDID:-}" ]; then
    printf '%s' "$IOS_SIMULATOR_UDID"
    return
  fi

  local devices booted
  devices="$(xcrun simctl list devices available)"
  booted="$(printf '%s\n' "$devices" | grep -E 'iPhone.*\(Booted\)' | head -1 || true)"
  if [ -z "$booted" ]; then
    booted="$(printf '%s\n' "$devices" | grep -E 'iPhone.*\([0-9A-Fa-f-]{36}\)' | head -1 || true)"
  fi
  [ -n "$booted" ] || fail "No available iPhone simulator found."
  printf '%s' "$booted" | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/'
}

boot_simulator() {
  local udid="$1"
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
}

ensure_certificate() {
  bash "$app_root/scripts/make-dev-cert.sh" >/dev/null
  xcrun simctl keychain "$1" add-root-cert "$app_root/.local-https/ca.pem" >/dev/null
}

server_pid=""
server_log=""

start_server() {
  local port="${1:-8443}"

  if curl -sk --max-time 2 "https://localhost:$port/__control/ping" 2>/dev/null | grep -q '^ok$'; then
    fail "Port $port already has a test server. Stop it before running the iOS checks."
  fi

  server_log="$(mktemp)"
  node "$app_root/scripts/serve-static-https.mjs" --port "$port" >"$server_log" 2>&1 &
  server_pid=$!

  local attempt
  for attempt in $(seq 1 50); do
    if ! kill -0 "$server_pid" 2>/dev/null; then
      cat "$server_log" >&2
      fail "The HTTPS test server exited before becoming ready."
    fi
    if curl -sk "https://localhost:$port/__control/ping" 2>/dev/null | grep -q '^ok$'; then
      return
    fi
    sleep 0.2
  done

  cat "$server_log" >&2
  fail "The HTTPS test server did not answer on port $port."
}

stop_server() {
  if [ -n "$server_pid" ] && kill -0 "$server_pid" 2>/dev/null; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  if [ -n "$server_log" ]; then
    rm -f "$server_log"
  fi
}
