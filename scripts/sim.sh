#!/usr/bin/env bash
# Standard simulator runner — consistent across the 4 sibling iOS apps
# (MiVista / Future / Nutrition / Swish). Pins iPhone 16 Pro Max by UDID so
# every build / install / launch / screenshot lands on the SAME device.
#
# Usage:
#   scripts/sim.sh run   [flags]     build + install + launch (+ screenshot)   [default]
#   scripts/sim.sh build             build only
#   scripts/sim.sh boot              boot the pinned sim + open Simulator
#   scripts/sim.sh shot  [seconds]   screenshot the running app
#
# Run flags (all optional; forwarded to the app, DEBUG builds only):
#   -c, --config-dir <dir>   load config from a LOCAL checkout instead of GitHub
#                            (disables the GitHub refresh). Relative paths are
#                            absolutized here so the simulator can read them.
#   --debug                  verbose dev logging inside the app
#   --gh-token <tok>         GitHub PAT       (else $GITHUB_TOKEN / $GH_TOKEN)
#   --anthropic-key <key>    Anthropic key    (else $ANTHROPIC_API_KEY)
#
# Credentials reach the app two ways (either works): as launch args, AND as
# SIMCTL_CHILD_* env vars injected into the launched process.
#
#   Override the device for a one-off:  SIM_DEVICE="iPhone 16 Pro" scripts/sim.sh run
set -euo pipefail

# ── Per-app identity (the ONLY lines that differ between apps) ────────────────
DEVICE="${SIM_DEVICE:-iPhone 16 Pro Max}"
APP_ID="com.sclaussen.nutrition"
SCHEME="nutrition"
PROJECT="nutrition.xcodeproj"
APP_NAME="Nutrition.app"
# ─────────────────────────────────────────────────────────────────────────────

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/dd/Build/Products/Debug-iphonesimulator/$APP_NAME"

udid() { xcrun simctl list devices available | grep -m1 "$DEVICE (" | grep -oiE "[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}"; }

boot() {
  local id; id="$(udid)"
  [ -z "$id" ] && { echo "No installed simulator named '$DEVICE'." >&2; exit 1; }
  # Only the pinned device should be booted, so you can't glance at the wrong
  # window. (User flagged this 2026-06-15.)
  for other in $(xcrun simctl list devices booted 2>/dev/null | grep -oE '\([0-9A-F-]{36}\)' | tr -d '()'); do
    if [ "$other" != "$id" ]; then
      echo "sim.sh: shutting down stray sim $other (only $DEVICE allowed)" >&2
      xcrun simctl shutdown "$other" 2>/dev/null || true
    fi
  done
  xcrun simctl list devices | grep "$id" | grep -q Booted || xcrun simctl boot "$id"
  open -a Simulator
  printf '%s' "$id"
}

build() {
  xcodebuild -project "$ROOT/$PROJECT" -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -derivedDataPath "$ROOT/build/dd" build 2>&1 | tail -3
}

# Parse run flags → LAUNCH_ARGS[] (forwarded to the app) + credential env.
# `-c/--config-dir` is absolutized (the sim can't resolve a relative path).
parse_run_flags() {
  LAUNCH_ARGS=()
  GH="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
  ANT="${ANTHROPIC_API_KEY:-}"
  while [ $# -gt 0 ]; do
    case "$1" in
      -c|--config-dir)
        local dir="$2"; shift 2
        dir="$(cd "$dir" 2>/dev/null && pwd)" || { echo "config-dir not found: $2" >&2; exit 1; }
        LAUNCH_ARGS+=(--config-dir "$dir") ;;
      --debug)         LAUNCH_ARGS+=(--debug); shift ;;
      --gh-token)      GH="$2"; shift 2 ;;
      --anthropic-key) ANT="$2"; shift 2 ;;
      *)               LAUNCH_ARGS+=("$1"); shift ;;
    esac
  done
  # Credentials also travel as launch args so the app can read either channel.
  [ -n "$GH" ]  && LAUNCH_ARGS+=(--gh-token "$GH")
  [ -n "$ANT" ] && LAUNCH_ARGS+=(--anthropic-key "$ANT")
  # …and as env, injected into the launched app via SIMCTL_CHILD_*.
  [ -n "$GH" ]  && export SIMCTL_CHILD_GITHUB_TOKEN="$GH"
  [ -n "$ANT" ] && export SIMCTL_CHILD_ANTHROPIC_API_KEY="$ANT"
}

case "${1:-run}" in
  build) build ;;
  boot)  boot; echo ;;
  shot)
    id="$(boot)"; sleep "${2:-3}"
    xcrun simctl io "$id" screenshot /tmp/sim.png && echo "screenshot: /tmp/sim.png ($DEVICE)"
    ;;
  run)
    shift || true
    parse_run_flags "$@"
    build
    id="$(boot)"
    xcrun simctl terminate "$id" "$APP_ID" 2>/dev/null || true
    xcrun simctl install "$id" "$APP"
    xcrun simctl launch "$id" "$APP_ID" "${LAUNCH_ARGS[@]}"
    sleep 4
    xcrun simctl io "$id" screenshot /tmp/sim.png
    echo "screenshot: /tmp/sim.png ($DEVICE)"
    ;;
  *) echo "usage: scripts/sim.sh [run|build|boot|shot]" >&2; exit 1 ;;
esac
