<div align="center">
  <img src="Sources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" alt="TrackPeek icon">

  # TrackPeek

  **Spotify and Apple Music controls for your menu bar, notch, and desktop.**
  See what's playing without leaving your current app.

  ![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)
  ![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
  [![Latest release](https://img.shields.io/github/v/release/Komortes/TrackPeek)](https://github.com/Komortes/TrackPeek/releases/latest)
</div>

TrackPeek is a native macOS companion for the Spotify and Apple Music desktop apps. Control playback from the menu bar, expand a notch player, or keep a widget on your chosen monitor. Read synchronized lyrics, use keyboard controls, and choose a resource mode that fits your Mac. A physical notch is optional for menu bar and desktop widgets.

**Release status:** 1.1 (build 2) is prepared as a draft and awaits publication approval. The latest public download is [1.0](https://github.com/Komortes/TrackPeek/releases/tag/v1.0); this README describes the current development version. See the [changelog](CHANGELOG.md) and [1.1 release notes](docs/releases/1.1.md).

## What you can do

- **Choose a surface:** menu bar, full or Focus notch, or ten desktop widgets—Pill, Mini Bar, Edge, horizontal/vertical cards, Artwork Square, Lyrics, Lyric Strip, Karaoke, and Equalizer. The popover offers Standard, Compact, Artwork, and Lyrics layouts.
- **Control playback:** play/pause, previous/next, seeking, and source-supported shuffle, repeat, and volume. Choose Spotify, Apple Music, or Automatic from Settings or the player menu.
- **Read lyrics:** synchronized lines, karaoke, or a full-song reader with line seeking, manual scrolling, retries, and timing adjustment. Lyrics come from LRCLIB when available.
- **Use your keyboard:** configurable global playback/visibility shortcuts, local five-second seeking, and one-percent volume steps. Controls expose focus and VoiceOver labels.
- **Place your player:** choose a named monitor, automatic placement, or all displays. A selected monitor is remembered across reconnections.
- **Manage resources:** Automatic follows Low Power Mode; Economical stops live audio analysis and decorative loops, slows polling, and retains appearance choices. Hidden expanded-notch clocks pause while collapsed.
- **Recover from interruptions:** bounded retries, stale-state feedback, diagnostics, and an isolated playback helper handle temporary errors and stalled scripts.
- **Personalize the app:** artwork accents, equalizer sensitivity, appearance presets, launch at login, and Sparkle update checks.

## Install

1. Download `TrackPeek-<version>.zip` from [Releases](https://github.com/Komortes/TrackPeek/releases).
2. Unzip it, move `TrackPeek.app` to `/Applications`, and open it.
3. Start Spotify or Apple Music and allow **Automation** access when macOS asks.
4. Choose a player and surface in onboarding or Settings. The menu bar remains available when the desktop overlay is off.

Requires **macOS 14 or later**. The live equalizer needs **macOS 14.2 or later** and audio-capture permission. The 1.1 archive supports Apple silicon and Intel; runtime verification was performed on an Apple silicon Mac with macOS 26.2. The interface currently uses Russian labels.

Releases use **Apple Development signing and are not notarized**. If macOS blocks first launch, follow [Apple's instructions](https://support.apple.com/en-asia/guide/mac-help/mh40616/mac) for a download you trust. See [release preparation](docs/RELEASING.md) for the distribution details.

## Controls and settings

Right-click the player or use its **…** menu for source selection, lyrics, copying metadata, appearance, hiding, refresh, and settings. **Source** (`Источник`) shares the saved preference with Settings; changing it refreshes the displayed source without starting playback.

Click progress to focus the control, then press **Left/Right** to seek five seconds. **Tab** moves between progress and volume where present; volume arrows change one percent. Global shortcuts are configured under **Settings → Shortcuts** (`Клавиши`) and are unassigned by default. Lyric Strip supports Space for play/pause and arrows for track changes while focused.

Settings groups General, Notch, Widget, Menu Bar, Shortcuts, Resources, and About. Placement, appearance, diagnostics, and login feedback are explained in the [usage guide](docs/USAGE.md).

## Privacy

Playback state and commands use local Apple Events through a bundled helper. No separate Spotify or Apple Music web login is required, and TrackPeek does not keep a listening-history database.

Lyrics requests send song metadata to LRCLIB. Remote artwork comes from the URL supplied by the player; Apple Music artwork uses a temporary local file. Sparkle reads the configured GitHub feed and downloads updates. Artwork and lyrics use bounded in-memory caches. Diagnostic reports are copied only on request and omit song metadata, user paths, and raw errors. See [network and permission behavior](docs/USAGE.md#privacy-and-network-use).

## Build from source

Use Xcode with **Swift 6** support and [XcodeGen](https://github.com/yonaskolb/XcodeGen). The current toolchain is Xcode 26.6.

```sh
brew install xcodegen
git clone https://github.com/Komortes/TrackPeek.git
cd TrackPeek
```

Configure your own `DEVELOPMENT_TEAM` and signing identity in `project.yml` for the app, helper, and tests, then:

```sh
xcodegen generate
./script/build_and_run.sh --verify
```

The helper builds Debug for arm64, stops the running TrackPeek process, and launches `.build/xcode/Build/Products/Debug/TrackPeek.app`. Use Xcode directly for another destination. Regenerate the project after adding files or changing configuration.

Run app-hosted tests with:

```sh
xcodebuild -project TrackPeek.xcodeproj -scheme TrackPeek \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/xcode test
```

The root `Package.swift` does not configure the complete app, Objective-C++ bridge, Sparkle dependency, or test target. Use the Xcode project. See [contributing](CONTRIBUTING.md) for release-script tests and review conventions.

## Repository guide

| Path | Contents |
| --- | --- |
| `Sources/Models`, `Services`, `Stores` | Playback state, preferences, source routing, audio, lyrics, and shared caches |
| `Sources/Views`, `Support` | SwiftUI surfaces, settings, AppKit windows, displays, and updates |
| `Helpers/`, `Shared/` | Isolated AppleScript process and bounded IPC protocol |
| `Tests/` | App-hosted regression tests |
| `script/` | Build/run, validated release preparation, and script tests |
| `project.yml`, `TrackPeek.xcodeproj` | XcodeGen definition and generated Xcode project |
| `docs/` | Usage, product plans, verification records, and release notes |

[Usage guide](docs/USAGE.md) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md) · [Releasing](docs/RELEASING.md) · [Product roadmap](docs/product/ROADMAP.md)
