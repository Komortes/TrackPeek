#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 path/to/TrackPeek.app path/to/new.dmg [en|uk|ru]"
}

if [[ ${1:-} == --help ]]; then usage; exit 0; fi
if [[ $# -lt 2 || $# -gt 3 ]]; then usage >&2; exit 2; fi
app=$1
output=$2
language=${3:-en}
case $language in en|uk|ru) ;; *) usage >&2; exit 2 ;; esac

if [[ ! -d $app || ! -f $app/Contents/Info.plist ]] ||
   [[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist") != com.trackpeek.TrackPeek ]] ||
   [[ ! -x $app/Contents/MacOS/TrackPeek ]]; then
  echo "Expected a built TrackPeek application bundle: $app" >&2
  exit 1
fi
if [[ $output != *.dmg || -e $output || -L $output ]]; then
  echo "Choose a new output filename ending in .dmg: $output" >&2
  exit 1
fi
root=$(cd "$(dirname "$0")/.." && pwd)
app=$(cd "$app" && pwd -P)
output_dir=$(cd "$(dirname "$output")" && pwd -P)
output="$output_dir/$(basename "$output")"
# Compare directory identities: APFS may resolve different spellings to the same bundle.
ancestor=$output_dir
while [[ "$ancestor" != / ]]; do
  if [[ "$ancestor" -ef "$app" ]]; then
    echo "Choose an output directory outside the app bundle." >&2
    exit 1
  fi
  ancestor=$(dirname "$ancestor")
done

if ! command -v dmgbuild >/dev/null; then
  echo "Install dmgbuild as described in docs/RELEASING.md, then add it to PATH." >&2
  exit 1
fi

# Link the verified image into place without overwriting a previous output.
work=$(mktemp -d "$output_dir/.trackpeek-dmg.XXXXXXXX")
trap 'rm -rf "$work"' EXIT
xcrun swift "$root/script/dmg/Background.swift" "$work" "$root/Sources/Resources/Localizable.xcstrings" "$language"
dmgbuild -s "$root/script/dmg/layout.py" -D "app=$app" -D "background=$work/background.png" TrackPeek "$work/TrackPeek.dmg"
hdiutil verify "$work/TrackPeek.dmg"
/bin/link "$work/TrackPeek.dmg" "$output"
