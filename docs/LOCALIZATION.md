# Localization

TrackPeek uses native Foundation/SwiftUI localization with English as the
development language and Ukrainian (`uk`) and Russian (`ru`) translations.
The development version includes a language selector in Settings → General →
App Language: Follow macOS, English, Українська, or Русский. An explicit choice
is stored in the app's `AppleLanguages` preference; Follow macOS removes only
that app override. Restart Now applies the selection and reopens Settings.
Published 1.1 build 4 still uses the per-app language controls in System Settings
→ General → Language & Region, followed by a relaunch.

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
- Keep playback preference raw values, commands, metadata, and lyrics unchanged.
  Read the language selection from the app's persistent defaults domain so the
  inherited global language list does not appear as an explicit selection.
  Never register an `AppleLanguages` default or write to the global domain.
- Use a relaunch rather than a SwiftUI-only locale override: existing
  `String(localized:)` calls and AppKit menus must use the same bundle language.
  Release the old process's global shortcuts before starting the replacement;
  restore them if launch fails and terminate only after successful launch.
  The selected language survives the appearance/player reset.
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
