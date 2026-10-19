# Changelog

Changes are grouped by release.

## 1.1 — 2026-10-19 (build 5)

- Choose English, Ukrainian, Russian, or Follow macOS directly in Settings → General → App Language. The choice is saved for TrackPeek and takes effect after restarting the app.
- A Restart Now button applies the pending language and reopens Settings. If relaunch fails, the current app stays open and its shortcuts are restored.

Build 5 is available in `TrackPeek-1.1-build5.zip`, with source recorded by [`v1.1-build5`](https://github.com/Komortes/TrackPeek/tree/v1.1-build5). Existing preferences are retained. The build 3 and build 4 archives and their public source tags remain unchanged for manual recovery.

## 1.1 — 2026-10-19 (build 4)

- English and Ukrainian localization across settings, onboarding, player menus, tooltips, accessibility, status messages and diagnostics, with Russian retained.
- Native macOS language selection, English fallback, localized permission explanations, decimal formatting and volume percentage plural forms.
- Long onboarding headings and descriptions wrap instead of being truncated.
- Removed README screenshots while a new visual direction is being considered.

Build 4 is available in `TrackPeek-1.1-build4.zip`. The original `TrackPeek-1.1.zip` remains available as build 3 for recovery; its public `v1.1` tag is unchanged. Build 4 source is recorded by [`v1.1-build4`](https://github.com/Komortes/TrackPeek/tree/v1.1-build4).

## 1.1 — 2026-10-19 (build 3)

### Settings improvements

- Compact Settings window with even margins and a simpler General page: music source, screen panel, visibility, then launch at login.
- Widget placement starts with the monitor and shows only the controls relevant to fixed positioning or free movement.
- Visible widget template categories, clearer subsection names, and lyrics options alongside the current template's appearance.
- Connection diagnostics keep status and recovery actions visible, with check times in expandable details.
- Widget appearance omits controls that do not apply to the current template; templates with no lyrics no longer start unnecessary lyrics lookups from a saved switch.
- MiniBar and Equalizer wave colors follow their own setting independently of progress color.

### Added

- Ten desktop widget templates, including Edge, Lyric Strip, Lyrics, Karaoke, and artwork cards.
- Named display selection with placement restored after monitor reconnection.
- Focus notch layout and a full-song Lyrics popover with line seeking and manual reading.
- Configurable global playback and overlay shortcuts, with conflict and registration feedback.
- Automatic, Normal, and Economical resource modes, connection diagnostics, and manual recovery.
- Quick source selection from player menus, lyrics retries, fallback matching, and timing adjustment.
- Local keyboard seeking and volume adjustment, focus indicators, and native artwork buttons.

### Changed

- Playback scripts run in a bounded, recoverable helper process; timed-out commands are never replayed automatically.
- Artwork downloads, decoded images, palettes, and lyrics share bounded caches.
- Settings and player menus group related actions; metadata and playback status are clearer for VoiceOver.
- Hidden expanded-notch progress and lyrics clocks pause while collapsed.
- Release preparation validates versions, universal binaries, signatures, download URLs, and SHA-256 checksums.

### Fixed

- Automatic source routing no longer reads a fallback twice or hides a paused song behind an empty snapshot.
- Obsolete lyrics requests are cancelled even when a lyrics view is closed.
- Launch-at-login errors and approval requirements are visible; the switch refreshes from macOS.
- Keyboard arrows work with the macOS Function modifier; rounded volume responses reconcile the displayed value.
- Non-finite timing, coordinates, and numeric preferences no longer cause unsafe conversion or layout values.
- Stale connection snapshots stop progress and audio analysis; stalled capture can recover.

## 1.0 — 2026-07-23

Initial release: a notch player with hover expansion and a live equalizer, a menu bar player, three popover layouts, Spotify and Apple Music support, artwork accents, launch at login, and Sparkle updates.

[Published release 1.0](https://github.com/Komortes/TrackPeek/releases/tag/v1.0) · [Release notes for 1.1](docs/releases/1.1.md)
