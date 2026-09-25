<div align="center">
  <img src="Sources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" alt="TrackPeek icon">

  # TrackPeek

  **Spotify and Apple Music controls for your menu bar, notch, and desktop.**
  See what's playing without leaving your current app.

  ![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)
  ![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
  ![Spotify](https://img.shields.io/badge/Spotify-supported-1DB954?logo=spotify&logoColor=white)
  ![Apple Music](https://img.shields.io/badge/Apple%20Music-supported-FA243C?logo=applemusic&logoColor=white)
</div>

TrackPeek controls the Spotify and Apple Music desktop apps already running on your Mac. Use the menu bar alone, expand a notch player on hover, or keep a floating widget on a monitor of your choice. A physical notch is not required for the menu bar or widgets.

## Features

- **Menu bar player** — optional track title, equalizer, and dedicated previous / play-pause / next buttons. The popover has Standard, Compact, Artwork, and Lyrics layouts.
- **Notch player** — choose the full artwork player or Focus, a smaller layout with title, playback controls, and progress, without artwork or visual effects.
- **Ten widget layouts** — Pill, Mini Bar, Edge, horizontal and vertical cards, Artwork Square, Lyrics, Lyric Strip, Karaoke, and Equalizer.
- **Lyric Strip** — one synchronized line in a 56 pt-high panel, with controls on hover or keyboard focus. Shows the track title when synchronized lyrics are unavailable; no artwork, equalizer, or animated border.
- **Edge** — a narrow vertical controller on either side of the screen, with permanent playback buttons and track details available from the artwork.
- **Multiple monitors** — choose a connected display by name, use an automatic placement policy, or show a panel on all screens. A selected monitor is remembered across reconnections.
- **Playback controls** — previous/next, play/pause, and seeking; larger layouts also expose shuffle, repeat, and volume where supported by the source.
- **Global shortcuts** — assign play/pause, previous/next, and overlay visibility in Settings → Shortcuts (`Клавиши`), with conflict feedback and an off switch. No keys are assigned by default.
- **Lyrics** — synchronized lyrics and karaoke from LRCLIB when available.
- **Artwork colors and live audio** — configurable accents, equalizer sensitivity, and visual effects. Audio analysis stops on pause and when no visible surface needs it; Reduce Motion is respected.
- **Spotify and Apple Music** — automatic source selection or a preferred player in Settings.
- **Connection recovery** — reconnects after sleep or player restarts, backs off after temporary errors, and keeps the last track visibly marked as stale with its progress stopped.
- **Resource modes** — Automatic follows macOS Low Power Mode; Normal and Economical override it. Economical stops live audio analysis and decorative looping effects, reduces progress updates and background polling, and preserves appearance choices.
- **Diagnostics** — Settings → General (`Основные`) shows connection, Automation, polling, and audio-analysis status, with a manual check and a copyable technical report.
- **Launch at login** and **update checks** through [Sparkle](https://sparkle-project.org).

## Install and get started

1. Download `TrackPeek-<version>.zip` from [Releases](https://github.com/Komortes/TrackPeek/releases).
2. Unzip it, move `TrackPeek.app` to `/Applications`, and open it.
3. Start Spotify or Apple Music. Allow **Automation** access when macOS asks so TrackPeek can read playback state and send controls.
4. Use onboarding or Settings to choose the player and surface. The menu bar remains available when the desktop overlay is off.
5. For a particular monitor, open **Settings → Widget → Show on** (`Настройки → Виджет → Показывать на`) and select its name. The notch settings have the same selector.

The app requires **macOS 14 or later**. The live equalizer requires **macOS 14.2 or later** and audio-capture permission when requested.

If macOS blocks a downloaded build because its developer cannot be verified, follow [Apple's guidance for opening an app from an unknown developer](https://support.apple.com/en-asia/guide/mac-help/mh40616/mac), provided you trust the download. The repository currently uses Apple Development signing; the release script does not perform notarization.

## Displays and placement

- **Named monitor:** stays selected across reconnections. If disconnected, the panel temporarily uses the primary display and returns when the selected monitor reconnects.
- **Automatic:** the widget prefers an external display; the notch surface appears only on a display with a physical notch.
- **Primary / Notched / All displays:** the existing placement policies remain available.
- **Free movement:** enable it in Widget settings to drag ordinary widgets by their background. Moving a single widget to another monitor saves that destination. Edge uses the monitor and left/right selectors instead of free dragging.

See [display selection details](docs/product/display-selection.md) for behavior and verification notes.

## Focus notch and Lyrics popover

- **Settings → Notch → Layout → Focus** (`Чёлка → Раскладка чёлки → Фокус`) selects the restrained notch layout. Its collapsed title avoids the camera gap on notched displays, and expanded controls sit below the safe top area. Width and height correction remain adjustable; the full player's effect settings are preserved.
- **Settings → Menu Bar → Player window → Lyrics** (`Menu Bar → Окно плеера → Текст`) opens a fixed-size reading panel. Synchronized lyrics show the current line and nearby lines, updating at lyric boundaries; plain text is manually scrollable and selectable. Missing lyrics and network failures have separate states, with retry for failures. Playback and seeking remain at the bottom.

Both layouts retain the existing menus and playback source. Lyrics uses the shared store, a neutral system background, and no artwork. Its lyric schedule and progress updates stop when the view closes; Focus creates its progress view only while expanded. Neither layout changes widget selection or overwrites other layouts' appearance choices.

## Lyric Strip widget

Choose **Settings → Widget → Lyrics → Lyric Strip** (`Виджет → Текст песни → Строка текста`). Its width is adjustable from 320 to 500 pt; its height stays at 56 pt. Use the existing placement controls to put it near the bottom of your chosen monitor or enable free movement.

The current lyric stays visible on pause. Before the first line, without synchronized lyrics, or during loading, the strip shows the current title and artist. Hover over the text to read its full version and status. A failed lyrics request exposes a retry button. Playback controls appear on hover, when the panel has keyboard focus, or with VoiceOver. With the strip focused, Space toggles playback and Left/Right changes tracks; configured global shortcuts also remain available.

The strip shares the lyrics cache with the other surfaces and schedules updates at lyric timestamps only while visible and playing. It does not request artwork palettes, audio analysis, pulse effects, or a shimmering outline. Other layouts retain their appearance settings.

## Finding lyrics and adjusting timing

TrackPeek first requests the exact lyrics record. If it is missing, one fallback search checks the title, artist and duration (within two seconds), allowing album differences and remaster suffixes. Live, Acoustic and Remix titles remain distinct. A matching album takes priority; competing lyric variants are rejected rather than selected by result order. Network failures stay retryable errors.

After **“Lyrics not found”** or a download error, use the retry button or **right-click / … → Lyrics → Search again** (`Текст песни → Повторить поиск`). Surfaces without lyrics can start a lookup with **Find lyrics** (`Найти текст`) in that menu. Repeated clicks share the active lookup.

For synchronized lyrics, the same menu offers **Earlier / Later by 0.5 s** and **Reset**. The adjustment applies to all lyrics surfaces, up to ten seconds in either direction. It stays in memory for the current recording only: changing the song or source clears it; seeking or repeating the same recording keeps it. Playback itself is not shifted and no adjustment history is saved.

Timed empty LRC lines now clear the previous lyric during instrumental gaps. The strip shows track information, the compact players show a music note, and the reading panel shows a subdued instrumental-gap label.

## Keyboard shortcuts

Open **Settings → Shortcuts (`Клавиши`)**, click an action's field, and press a combination containing **Command or Control**. Escape cancels recording; Delete clears the binding. The global switch releases the shortcuts while keeping your choices. Assignments survive relaunch and use physical key positions; labels follow the current keyboard layout.

TrackPeek checks duplicates, macOS symbolic shortcuts, common app commands, and registration errors. Some application-specific conflicts cannot be detected in advance. If a saved shortcut is unavailable at launch, its row shows an error and a retry button. While recording a new shortcut, TrackPeek temporarily releases its shortcuts.

Playback actions control the current ready source; they do not launch a player or queue commands during an outage. **Show/hide overlay** applies to the selected widget or notch and respects its visibility policy; it does nothing in Menu Bar-only mode.

Shortcuts use system hot-key registration without polling, broad keyboard monitoring, or additional Accessibility/Input Monitoring permissions.

## Resource usage

Choose **Settings → General → Resources** (`Основные → Ресурсы`). **Automatic** is the default and follows macOS Low Power Mode, including changes while TrackPeek is running. Battery power alone does not activate it. On Macs where the system mode is unsupported, Automatic behaves like Normal; Economical remains available manually.

**Economical** keeps the equalizer static, stops audio capture, pulse effects and shimmering borders, and updates playback progress once a second. Healthy playback polls change from 2 to 5 seconds while playing and from 4 to 8 seconds while paused. External track changes can therefore take up to five seconds to appear. Clicks, seeking, global shortcuts and manual refresh still run immediately; connection recovery retains its existing backoff.

Appearance settings are preserved and restored when economy ends, subject to Reduce Motion and existing visibility rules. Synchronized lyrics retain their timing; this mode does not disable lyrics loading or change the bounded artwork/lyrics caches. The Resources section shows whether economy is currently active; Diagnostics explains when audio analysis is stopped for economy.

Artwork keeps its current image while a different resolution of the same cover loads. A new track clears the previous cover immediately. Loading indicators appear only after a short delay and stay static in small artwork slots, Reduce Motion, and Economical mode; missing or failed artwork uses a sized music-note placeholder.

## Privacy and network use

Playback state and commands use local **AppleScript / Apple Events**. TrackPeek does not require a separate Spotify or Apple Music web login.

Some features use the network:

- Lyrics requests send the track title, artist, duration, and album (when available) to **LRCLIB**.
- Remote artwork is loaded from the URL supplied by the player. Apple Music artwork is read from the local app and written to a temporary file.
- Sparkle checks the configured GitHub release feed and downloads updates.

TrackPeek does not keep a listening-history database. Artwork data, decoded images, palettes, and lyrics use bounded in-memory caches. Artwork downloads share an ephemeral session without an additional HTTP cache. Diagnostic reports are copied only on request and exclude song metadata, user paths, and raw error messages.

If Automation access is denied, automatic polling stops until you retry or a relevant lifecycle event occurs. Open **Settings → General → Diagnostics** to reach macOS permissions and check again. Recovery does not automatically replay playback commands. A permanently blocked native AppleScript engine still requires a TrackPeek restart; isolating that engine in a helper process is planned.

## Build from source

Use **Xcode with Swift 6 support** and [XcodeGen](https://github.com/yonaskolb/XcodeGen). The current development toolchain is Xcode 26.6. The helper script and commands below target **Apple silicon (`arm64`)**.

```sh
brew install xcodegen
git clone https://github.com/Komortes/TrackPeek.git
cd TrackPeek
```

Before building, set `DEVELOPMENT_TEAM` in **both targets** in `project.yml` to your own Apple development team. Configure `CODE_SIGN_STYLE` and the signing identity for your local setup; the checked-in values belong to the maintainer. A matching signing certificate must be available in Keychain.

```sh
xcodegen generate
./script/build_and_run.sh --verify
```

The script stops any running TrackPeek process, builds the Debug app, and launches it from `.build/xcode/Build/Products/Debug/TrackPeek.app`. To update the copy shown in the app library, quit TrackPeek and replace `/Applications/TrackPeek.app` with the newly built app. It also supports `--debug`, `--logs`, and `--telemetry`. You can open `TrackPeek.xcodeproj` in Xcode to select a different build destination or configure signing interactively; regenerating the project replaces manual project-file changes with `project.yml` settings.

### Tests

Build and run the app-hosted tests through the Xcode project:

```sh
xcodebuild \
  -project TrackPeek.xcodeproj \
  -scheme TrackPeek \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/xcode \
  test
```

The root `Package.swift` is not the app's supported build/test entry point: it does not configure the app's Objective-C++ bridge, Sparkle dependency, or test target.

### Preparing a release

For maintainers with the app-signing identity and the Sparkle signing key matching the configured public key:

```sh
./script/release.sh 1.1
```

This changes `MARKETING_VERSION` in `project.yml`, regenerates the Xcode project, builds the app, and creates a ZIP and signed appcast in `.build/release/1.1/`. It prints the publishing command; it does **not** publish a GitHub release or notarize the app. Review the version changes and generated artifacts before publishing.

## Project layout

```text
Sources/
  Models/     — playback state, layouts, display selection, preferences
  Services/   — AppleScript clients, source routing, audio and lyrics
  Stores/     — shared playback state and bounded lyrics cache
  Support/    — windows, display identity, updates, palette extraction
  Views/      — notch, widgets, menu bar, popover layouts, settings
Tests/        — app-hosted tests run with xcodebuild
script/       — build/run and release helpers
project.yml   — XcodeGen project definition
```

[Product roadmap](docs/product/ROADMAP.md) · [Stability and resource review](docs/reviews/2026-09-08-stability.md)
