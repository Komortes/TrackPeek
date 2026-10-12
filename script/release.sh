#!/usr/bin/env bash
set -euo pipefail

# Prepare local, development-signed artifacts. Publishing is a separate step.
usage() { echo "Usage: script/release.sh <version, e.g. 1.1> <build, e.g. 2>"; }
fail() { echo "Error: $*" >&2; exit 1; }
if [[ "${1:-}" == "--help" && $# -eq 1 ]]; then usage; exit 0; fi
[[ $# -eq 2 ]] || { usage >&2; exit 1; }
VERSION="$1"
BUILD_NUMBER="$2"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || fail "Version must contain two or three numeric components."
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || fail "Build number must be a positive integer without leading zeros."
APP_NAME="TrackPeek"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/.build/release/$VERSION"
DERIVED_DATA="$ROOT_DIR/.build/xcode-release"
NOTES_PATH="$ROOT_DIR/docs/releases/$VERSION.md"
REPOSITORY_URL="https://github.com/Komortes/TrackPeek"
DOWNLOAD_PREFIX="$REPOSITORY_URL/releases/download/v$VERSION/"

[[ ! -e "$RELEASE_DIR" ]] || fail "Release directory already exists: $RELEASE_DIR. Preserve or move it before rebuilding."
CONFIG_VERSION="$(awk '/^[[:space:]]*MARKETING_VERSION:/ {gsub(/\"/, "", $2); print $2}' "$ROOT_DIR/project.yml")"
CONFIG_BUILD="$(awk '/^[[:space:]]*CURRENT_PROJECT_VERSION:/ {gsub(/\"/, "", $2); print $2}' "$ROOT_DIR/project.yml")"
[[ "$CONFIG_VERSION" == "$VERSION" && "$CONFIG_BUILD" == "$BUILD_NUMBER" ]] || fail "Set project.yml to version $VERSION and build $BUILD_NUMBER before preparing this release."
[[ -s "$NOTES_PATH" ]] || fail "Release notes are missing: $NOTES_PATH"
for command in xcodegen xcodebuild xcrun ditto codesign lipo xmllint shasum; do
  command -v "$command" >/dev/null || fail "Required tool is unavailable: $command"
done

cd "$ROOT_DIR"
xcodegen generate --spec project.yml
xcodebuild \
  -project "$ROOT_DIR/TrackPeek.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  build

APP_BUNDLE="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
HELPER="$APP_BUNDLE/Contents/Helpers/TrackPeekScriptHelper"
PLIST="$APP_BUNDLE/Contents/Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")" == "$VERSION" ]] || fail "Built app has the wrong version."
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")" == "$BUILD_NUMBER" ]] || fail "Built app has the wrong build number."
lipo "$APP_BUNDLE/Contents/MacOS/$APP_NAME" -verify_arch arm64 x86_64
lipo "$HELPER" -verify_arch arm64 x86_64
codesign --verify --strict --verbose=2 "$HELPER"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

SPARKLE_BIN="$DERIVED_DATA/SourcePackages/artifacts/sparkle/Sparkle/bin"
[[ -x "$SPARKLE_BIN/generate_appcast" && -x "$SPARKLE_BIN/generate_keys" ]] || fail "Sparkle release tools are unavailable after building."
EXPECTED_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$PLIST")"
[[ "$("$SPARKLE_BIN/generate_keys" -p)" == "$EXPECTED_KEY" ]] || fail "Existing Sparkle signing key does not match the app's public key."

mkdir -p "$RELEASE_DIR"
ZIP_PATH="$RELEASE_DIR/$APP_NAME-$VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"
# Plain text notes remain readable by the Sparkle version shipped in 1.0.
sed -E 's/^#{1,6} //; s/\*\*//g; s/`//g' "$NOTES_PATH" > "$RELEASE_DIR/$APP_NAME-$VERSION.txt"
"$SPARKLE_BIN/generate_appcast" \
  --download-url-prefix "$DOWNLOAD_PREFIX" \
  --link "$REPOSITORY_URL/releases/tag/v$VERSION" \
  --full-release-notes-url "$REPOSITORY_URL/blob/main/CHANGELOG.md" \
  --embed-release-notes "$RELEASE_DIR"

APPCAST="$RELEASE_DIR/appcast.xml"
item_value() { xmllint --xpath "string(/rss/channel/item/*[local-name()='$1'])" "$APPCAST"; }
xmllint --noout "$APPCAST"
[[ "$(xmllint --xpath 'count(/rss/channel/item)' "$APPCAST")" == "1" ]] || fail "Expected exactly one update."
[[ "$(item_value version)" == "$BUILD_NUMBER" && "$(item_value shortVersionString)" == "$VERSION" ]] || fail "Appcast version does not match the app."
[[ "$(xmllint --xpath 'string(/rss/channel/item/enclosure/@url)' "$APPCAST")" == "$DOWNLOAD_PREFIX$APP_NAME-$VERSION.zip" ]] || fail "Appcast archive URL is incorrect."
[[ "$(xmllint --xpath 'string(/rss/channel/item/enclosure/@length)' "$APPCAST")" == "$(stat -f '%z' "$ZIP_PATH")" ]] || fail "Appcast archive size is incorrect."
[[ -n "$(item_value description)" ]] || fail "Appcast release notes are missing."
SIGNATURE="$(xmllint --xpath 'string(/rss/channel/item/enclosure/@*[local-name()="edSignature"])' "$APPCAST")"
[[ -n "$SIGNATURE" ]] || fail "Appcast archive signature is missing."
xcrun swiftc -parse-as-library -module-cache-path "$ROOT_DIR/.build/release-swift-cache" \
  "$ROOT_DIR/script/verify_update.swift" -o "$ROOT_DIR/.build/verify-update"
"$ROOT_DIR/.build/verify-update" "$PLIST" "$ZIP_PATH" "$SIGNATURE"

cd "$RELEASE_DIR"
shasum -a 256 "$APP_NAME-$VERSION.zip" appcast.xml > SHA256SUMS
shasum -a 256 -c SHA256SUMS

echo
echo "Prepared TrackPeek $VERSION (build $BUILD_NUMBER), universal arm64 + x86_64."
echo "Artifacts: $RELEASE_DIR"
echo "Signing: Apple Development; not notarized. Nothing was published."
echo
echo "After reviewing, committing, and pushing the release source, create a draft"
echo "using the exact commit SHA and docs/releases/$VERSION.md. See docs/RELEASING.md."
