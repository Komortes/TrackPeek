# Localization

TrackPeek uses native Foundation/SwiftUI localization with English as the
development language and Ukrainian (`uk`) and Russian (`ru`) translations.
The app follows macOS language preferences, including the per-app language
selection in System Settings → General → Language & Region. Relaunch TrackPeek
after changing its language.

User-facing text includes settings, onboarding, player states, menus, help,
accessibility descriptions, diagnostics and permission explanations. Song
metadata, lyrics, display names, protocol values and saved preference identifiers
are not translated.

## Implementation and verification

- Use `String(localized: "General")` when producing a `String` for shared views,
  models or AppKit. Keep interpolation inside the localized literal, for example
  `String(localized: "Open \(sourceName)")`.
- Store translations in `Sources/Resources/Localizable.xcstrings` and permission
  descriptions in `InfoPlist.xcstrings`. Keep language and resource settings in
  `project.yml`; regenerate `TrackPeek.xcodeproj` with `xcodegen generate`.
- Do not change persisted raw values, playback commands, metadata or user
  preferences to select a language. No custom runtime locale override is needed.
- Verify catalog coverage and formatting arguments, run the app-hosted test
  suite, and inspect Settings, player menus and onboarding in English and
  Ukrainian. Test bundles load explicit language resources so assertions do not
  depend on the developer's system language.

Run `python3 script/validate_localizations.py` to check all three translations
and their formatting arguments. Ukrainian and Russian volume percentages use
native plural variations for one, few, many and other; language-specific tests
provide both an explicit resource bundle and locale.

Build and test commands are in [CONTRIBUTING.md](../CONTRIBUTING.md#verification).
Localized builds remain macOS 14-compatible. App releases are prepared separately
using the existing release workflow.
