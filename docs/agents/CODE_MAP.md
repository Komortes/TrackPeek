# Карта кода для задач

Пути ниже относятся к текущему репозиторию. Начни с строки нужной области,
затем прочитай сами реализации и тесты; карта не заменяет контрактов в коде.

| Область | Точки входа | Соседние тесты в `Tests/` |
| --- | --- | --- |
| Startup и lifecycle | `Sources/TrackPeekApp.swift`, `Stores/PlaybackCoordinator.swift` | `PlaybackRecoveryTests.swift`, `SpotifySpikeModelTests.swift` |
| Snapshot и команды | `Stores/SpotifySpikeModel.swift`, `Models/PlaybackAvailability.swift`, `Models/PlaybackCapabilities.swift` | `SpotifySpikeModelTests.swift`, `PlaybackCapabilitiesTests.swift`, `PlaybackPositionResolverTests.swift` |
| Выбор Spotify/Music | `Services/PlaybackSourceRouter.swift`, `Services/SpotifyAppleScriptClient.swift`, `Services/MusicAppleScriptClient.swift` | `PlaybackRecoveryTests.swift`, `SpotifyTrackParserTests.swift` |
| AppleScript process и IPC | `Services/AppleScriptExecutor.swift`, `Helpers/TrackPeekScriptHelper/main.swift`, `Shared/AppleScriptIPC.swift` | `AppleScriptExecutorTests.swift`, `AppleScriptIPCTests.swift` |
| Lyrics | `Stores/LyricsStore.swift`, `Services/LyricsService.swift`, `Services/LyricsMatch.swift`, `Views/SyncedLyricsReader.swift` | `LyricsServiceTests.swift`, `LyricsLookupTests.swift`, `LyricsReaderNavigationTests.swift`, `SyncedLyricsReaderTests.swift` |
| Artwork | `Services/ArtworkDataLoader.swift`, `Services/ArtworkImageLoader.swift`, `Views/SharedArtworkImage.swift`, `Support/ArtworkPalette.swift` | `ArtworkImageLoaderTests.swift`, `ArtworkPaletteTests.swift` |
| Audio и ресурсы | `Services/SpotifyAudioMonitor.swift`, `Support/TPAudioLevelAnalyzer.mm`, `Support/AudioCaptureHealth.swift`, `Models/ResourceUsageMode.swift` | `AudioSpectrumTests.swift`, `AudioCaptureHealthTests.swift`, `PlaybackRecoveryTests.swift` |
| Окна, мониторы, виджеты | `Support/NotchWindowController.swift`, `Models/OverlayDisplayResolver.swift`, `Models/WidgetPlacementStore.swift`, `Views/Overlay/` | `OverlayDisplayResolverTests.swift`, `WidgetPlacementStoreTests.swift`, `NotchInteractionStateTests.swift`, `OverlayVisibilityTests.swift` |
| Настройки и layouts | `Views/SettingsView.swift`, `Models/WidgetPreferences.swift`, `Models/NotchConfiguration.swift`, `Models/PlayerPresets.swift` | `WidgetPreferencesTests.swift`, `NotchConfigurationTests.swift`, `PlayerLayoutTests.swift`, `PlayerPresetsTests.swift`, `NumericPreferenceTests.swift` |
| Shortcuts и клавиатура | `Support/GlobalShortcutsController.swift`, `Support/CarbonShortcutBackend.swift`, `Support/PlaybackKeyboardInput.swift` | `GlobalShortcutsTests.swift`, `PlaybackKeyboardInputTests.swift`, `LyricStripTests.swift` |
| Язык, relaunch, login | `Models/AppLanguage.swift`, `Views/LanguageSettingsView.swift`, `Support/ApplicationRelauncher.swift`, `Support/LaunchAtLogin.swift` | `AppLanguageTests.swift`, `ApplicationRelauncherTests.swift`, `LaunchAtLoginTests.swift`, `LocalizationTests.swift` |
| CI и релизы | `script/ci.sh`, `script/release.sh`, `script/verify_update.swift`, `project.yml`, `.github/workflows/ci.yml` | `script/tests/`, вне app target |

Сокращённые пути `Stores/`, `Models/`, `Services/`, `Views/`, `Support/`
в таблице начинаются в `Sources/`; `Helpers/`, `Shared/`, `script/` — в корне.

## Существенные границы

- `TrackPeekAppDelegate` не запускает обычные сервисы в XCTest host. Сохраняй
  этот guard: реальный polling и window controllers мешают изолированным тестам.
- `PlaybackCoordinator` управляет расписанием и lifecycle. `SpotifySpikeModel`
  хранит snapshot, объединяет чтения и отклоняет устаревшие результаты.
  Имя модели историческое: она уже обслуживает оба источника.
- `PlaybackSourceRouter` выбирает provider; команды должны относиться к источнику
  показанного snapshot. Автовыбор нельзя выводить только из сохранённой preference.
- `AppleScriptExecutor` управляет ограниченной очередью и helper-процессом.
  Приложение не выполняет `NSAppleScript` самостоятельно.
- `LyricsStore` отменяет старые запросы и хранит ограниченный кэш; чтение из
  SwiftUI `body` не должно само запускать сеть. Artwork также использует общие loaders.
- `NotchWindowController` содержит AppKit-поведение панелей. Resolver-тесты
  геометрии не заменяют native UI и проверку физических экранов.

Для нового поведения сначала ищи существующий тестовый provider/clock/defaults
в соседних тестах. Неподтверждённый рефакторинг архитектуры не входит автоматически
в исправление одного дефекта.
