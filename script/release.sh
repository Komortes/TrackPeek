#!/usr/bin/env bash
set -euo pipefail

# Builds a Release TrackPeek.app, bumps the version, signs a Sparkle
# appcast entry for it, and prints the GitHub Release steps to publish it.
#
# Usage: script/release.sh 1.1

VERSION="${1:?usage: script/release.sh <version, e.g. 1.1>}"
APP_NAME="TrackPeek"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/.build/release/$VERSION"
DERIVED_DATA="$ROOT_DIR/.build/xcode-release"

mkdir -p "$RELEASE_DIR"

sed -i '' -E "s/MARKETING_VERSION: \".*\"/MARKETING_VERSION: \"$VERSION\"/" "$ROOT_DIR/project.yml"

cd "$ROOT_DIR"
xcodegen generate --spec project.yml

xcodebuild \
  -project "$ROOT_DIR/TrackPeek.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  build

APP_BUNDLE="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
ZIP_PATH="$RELEASE_DIR/$APP_NAME-$VERSION.zip"

ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

SPARKLE_BIN="$(find "$ROOT_DIR/.build" ~/Library/Developer/Xcode/DerivedData -maxdepth 6 -type d -path '*artifacts/sparkle/Sparkle/bin' 2>/dev/null | head -1)"
if [ -z "$SPARKLE_BIN" ]; then
  echo "Could not locate Sparkle's bin/ directory under DerivedData — run a normal Debug build first." >&2
  exit 1
fi

"$SPARKLE_BIN/generate_appcast" "$RELEASE_DIR"

echo
echo "Release archive: $ZIP_PATH"
echo "Signed appcast:  $RELEASE_DIR/appcast.xml"
echo
echo "Next steps:"
echo "  gh release create v$VERSION \"$ZIP_PATH\" \"$RELEASE_DIR/appcast.xml\" --title \"TrackPeek $VERSION\""
echo
echo "SUFeedURL always points at the *latest* release's appcast.xml, so make sure"
echo "this is the newest published release before announcing it."
