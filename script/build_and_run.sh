#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--help]"
}

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi

MODE="${1-run}"
case "$MODE" in
  --help) usage; exit 0 ;;
  run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify) ;;
  *) usage >&2; exit 2 ;;
esac

APP_NAME="TrackPeek"
BUNDLE_ID="com.trackpeek.TrackPeek"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/xcode"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

xcodebuild \
  -project "$ROOT_DIR/TrackPeek.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Debug \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "$DERIVED_DATA" \
  build \
  -quiet

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    ;;
esac
