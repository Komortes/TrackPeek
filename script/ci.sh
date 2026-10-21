#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_ROOT="$ROOT_DIR/.build/ci"
DERIVED_DATA_ROOT="$ROOT_DIR/.build/ci-derived-data"
PYTHON="${TRACKPEEK_PYTHON:-/usr/bin/python3}"
MODE="${1:-all}"

usage() {
  echo "usage: $0 [checks|test|build|all]" >&2
}

if [[ $# -gt 1 ]]; then
  usage
  exit 2
fi
case "$MODE" in
  checks|test|build|all) ;;
  *) usage; exit 2 ;;
esac

fail() {
  echo "error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required tool '$1' is unavailable."
}

require_macos() {
  [[ "$(uname -s)" == Darwin ]] || fail "TrackPeek CI requires macOS and Xcode."
  require_command xcodebuild
  require_command xcrun
  xcodebuild -version
  xcrun swiftc --version
}

check_project_generation() {
  local scratch_dir
  scratch_dir="$(mktemp -d "$REPORT_DIR/project-generation.XXXXXX")"
  # Keep the same relative layout without rewriting the developer's project.
  cp "$ROOT_DIR/project.yml" "$scratch_dir/project.yml"
  for source_dir in Sources Shared Helpers Tests Config; do
    cp -R "$ROOT_DIR/$source_dir" "$scratch_dir/$source_dir"
  done
  xcodegen generate --no-env --spec "$scratch_dir/project.yml" --project "$scratch_dir"
  diff -u "$ROOT_DIR/TrackPeek.xcodeproj/project.pbxproj" \
    "$scratch_dir/TrackPeek.xcodeproj/project.pbxproj"
  diff -u "$ROOT_DIR/TrackPeek.xcodeproj/xcshareddata/xcschemes/TrackPeek.xcscheme" \
    "$scratch_dir/TrackPeek.xcodeproj/xcshareddata/xcschemes/TrackPeek.xcscheme"
  diff -u "$ROOT_DIR/Sources/Info.plist" "$scratch_dir/Sources/Info.plist"
  rm -rf "$scratch_dir"
}

checks() {
  require_macos
  for tool in "$PYTHON" actionlint shellcheck xcodegen; do
    require_command "$tool"
  done
  "$PYTHON" --version
  actionlint -version
  shellcheck --version
  xcodegen --version
  git diff --check
  git show --format= --check HEAD
  actionlint
  for shell_script in "$ROOT_DIR"/script/*.sh; do
    bash -n "$shell_script"
    shellcheck "$shell_script"
  done
  plutil -lint "$ROOT_DIR/Sources/Info.plist" "$ROOT_DIR/Config/TrackPeek.entitlements"
  check_project_generation
  "$PYTHON" -m unittest discover -s "$ROOT_DIR/script/tests" -p 'test_*.py' -v
  "$PYTHON" "$ROOT_DIR/script/validate_localizations.py"
  xcrun swiftc -D SIGNATURE_TESTS "$ROOT_DIR/script/verify_update.swift" \
    "$ROOT_DIR/script/tests/VerifyUpdateTests.swift" -o "$REPORT_DIR/verify-update-tests"
  "$REPORT_DIR/verify-update-tests"
}

xcode_arguments() {
  XCODE_ARGS=(
    -project "$ROOT_DIR/TrackPeek.xcodeproj"
    -scheme TrackPeek
    -onlyUsePackageVersionsFromResolvedFile
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY=-
    DEVELOPMENT_TEAM=
    PROVISIONING_PROFILE_SPECIFIER=
    CODE_SIGNING_ALLOWED=YES
    CODE_SIGNING_REQUIRED=YES
    OTHER_CODE_SIGN_FLAGS=--timestamp=none
  )
}

collect_test_reports() {
  local test_status=$?
  trap - EXIT
  if [[ -d "$RESULT_BUNDLE" ]]; then
    xcrun xcresulttool get test-results summary --path "$RESULT_BUNDLE" \
      > "$REPORT_DIR/test-summary.json" 2> "$REPORT_DIR/test-summary.log" \
      || echo "warning: Test summary could not be exported; inspect the xcresult."
    xcrun xccov view --report --json "$RESULT_BUNDLE" \
      > "$REPORT_DIR/coverage.json" 2> "$REPORT_DIR/coverage-export.log" \
      || echo "warning: Coverage JSON could not be exported; inspect the xcresult."
    xcrun xccov view --report "$RESULT_BUNDLE" \
      > "$REPORT_DIR/coverage.txt" 2>> "$REPORT_DIR/coverage-export.log" \
      || echo "warning: Coverage text could not be exported; inspect the xcresult."
  fi
  echo "Test command exit status: $test_status"
  exit "$test_status"
}

test() {
  require_macos
  local native_arch
  native_arch="$(uname -m)"
  case "$native_arch" in
    arm64|x86_64) ;;
    *) fail "Unsupported test host architecture: $native_arch" ;;
  esac
  xcode_arguments
  RESULT_BUNDLE="$REPORT_DIR/TrackPeekTests.xcresult"
  # xcodebuild refuses to overwrite an existing result bundle on local reruns.
  rm -rf "$RESULT_BUNDLE"
  trap collect_test_reports EXIT
  # The app's XCTest startup guard prevents player polling and permission prompts.
  # Ad-hoc test hosts cannot use team-based library validation for Sparkle.
  xcodebuild "${XCODE_ARGS[@]}" \
    -configuration Debug \
    -destination "platform=macOS,arch=$native_arch" \
    -derivedDataPath "$DERIVED_DATA_ROOT/test" \
    -resultBundlePath "$RESULT_BUNDLE" \
    -enableCodeCoverage YES \
    -parallel-testing-enabled NO \
    ENABLE_HARDENED_RUNTIME=NO \
    test
  [[ -x "$DERIVED_DATA_ROOT/test/Build/Products/Debug/TrackPeek.app/Contents/Helpers/TrackPeekScriptHelper" ]] \
    || fail "The app-hosted test build is missing its embedded script helper."
}

build() {
  require_macos
  xcode_arguments
  xcodebuild "${XCODE_ARGS[@]}" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_ROOT/build" \
    ONLY_ACTIVE_ARCH=NO \
    'ARCHS=arm64 x86_64' \
    ENABLE_HARDENED_RUNTIME=YES \
    build
  local app_bundle="$DERIVED_DATA_ROOT/build/Build/Products/Release/TrackPeek.app"
  local executable
  for executable in \
    "$app_bundle/Contents/MacOS/TrackPeek" \
    "$app_bundle/Contents/Helpers/TrackPeekScriptHelper"; do
    [[ -x "$executable" ]] || fail "Missing executable: $executable"
    xcrun lipo "$executable" -verify_arch arm64 x86_64
    xcrun lipo -archs "$executable"
  done
  codesign --verify --deep --strict --verbose=2 "$app_bundle"
  echo "Universal Release app and embedded helper verified. This ad-hoc build is for CI only."
}

run_mode() {
  local stage="$1"
  REPORT_DIR="$REPORT_ROOT/$stage"
  mkdir -p "$REPORT_DIR"
  echo "Running $stage; report: $REPORT_DIR/run.log"
  (
    set -euo pipefail
    cd "$ROOT_DIR"
    "$stage"
  ) 2>&1 | tee "$REPORT_DIR/run.log"
}

if [[ "$MODE" == all ]]; then
  run_mode checks
  run_mode test
  run_mode build
else
  run_mode "$MODE"
fi
