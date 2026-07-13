# TrackPeek

> Рабочее название концепта: **Now Playing+**  
> Платформа: **macOS**  
> Язык: **Swift**  
> Статус: **проектирование MVP**

## 1. Идея

TrackPeek — небольшое menu bar-приложение для управления уже запущенным Spotify.

Приложение не является отдельным Spotify-клиентом, не воспроизводит музыку самостоятельно и не требует постоянно держать открытым большое окно. Оно показывает текущий трек в строке меню и предоставляет компактный popover с основными действиями.

Основной сценарий:

1. Пользователь запускает Spotify.
2. TrackPeek автоматически определяет текущий трек.
3. В menu bar отображается иконка, название трека или исполнитель — в зависимости от настройки.
4. По нажатию открывается компактный плеер.
5. Пользователь управляет воспроизведением, не переключаясь в Spotify.

## 2. Зачем делать

Проект подходит как первый серьёзный Swift/macOS-проект, потому что затрагивает:

- Swift и Swift Concurrency;
- SwiftUI;
- `MenuBarExtra`;
- небольшую интеграцию с AppKit;
- Apple Events / управление другим приложением;
- отслеживание запущенных приложений;
- permissions macOS;
- локальное хранение настроек;
- асинхронное обновление состояния;
- работу с изображениями и сетевой загрузкой обложек;
- архитектуру с заменяемым источником playback-данных.

При этом MVP остаётся достаточно маленьким, чтобы его реально закончить.

## 3. Название

### Рекомендуемое рабочее название

**TrackPeek**

Плюсы:

- короткое;
- понятно передаёт смысл «быстро посмотреть текущий трек»;
- не привязано намертво к Spotify;
- подойдёт, если позже появится поддержка Apple Music или других плееров.

Перед публичным релизом потребуется отдельно проверить App Store, GitHub, домены и торговые марки.

### Альтернативы

- **TunePeek** — мягче и более музыкально;
- **Playline** — хорошо подходит для строки меню;
- **Trackline** — нейтрально и расширяемо;
- **NowBar** — максимально понятно, но слишком общее;
- **Playhead** — сильное название, но термин уже часто используется;
- **Now Playing+** — понятно как название концепта, но слабее как самостоятельный бренд.

## 4. MVP

### Menu bar

Настраиваемые варианты отображения:

- только иконка;
- исполнитель;
- название трека;
- `Исполнитель — трек`;
- название трека и текущая позиция;
- автоматическое сокращение длинной строки.

Примеры:

```text
♫
♫ Radiohead
♫ Jigsaw Falling Into Place
♫ Radiohead — Jigsaw Falling Into Place
♫ Jigsaw Falling Into Place · 2:31
```

Строка должна быть короткой и не занимать половину menu bar. Длинные названия сокращаются.

### Popover

Компактное окно примерно 320–380 px шириной:

- обложка;
- название трека;
- исполнитель;
- альбом;
- прогресс;
- текущее время и длительность;
- play/pause;
- previous;
- next;
- открыть Spotify;
- состояние «Spotify не запущен».

### Настройки

- формат строки menu bar;
- максимальная длина текста;
- показывать или скрывать иконку;
- показывать прогресс;
- запускать TrackPeek при входе в систему;
- частота обновления;
- поведение при закрытом Spotify;
- светлая, тёмная или системная тема, если понадобится отдельная настройка.

## 5. Что не входит в MVP

- собственный аудиоплеер;
- логин через Spotify;
- Spotify Web API;
- управление очередью;
- lyrics;
- музыкальная статистика;
- синхронизация между устройствами;
- поддержка нескольких музыкальных сервисов;
- глобальная история прослушивания;
- сложный эквалайзер;
- отдельное большое окно библиотеки.

Это намеренно откладывается, чтобы первая версия не превратилась в бесконечный комбайн.

## 6. Технический стек

### Основной стек

- **Swift 6.x**
- **SwiftUI**
- **AppKit** — только там, где SwiftUI недостаточно
- **macOS 14+** как первоначальный deployment target
- **Xcode toolchain и macOS SDK**
- **VS Code** как основной редактор
- **xcodebuild** для сборки из терминала
- **Swift Testing или XCTest**
- **SwiftFormat / SwiftLint** — добавить после появления базового проекта

### Системные технологии

- `MenuBarExtra` — menu bar-интерфейс;
- `Settings` scene — отдельное окно настроек;
- `NSWorkspace` — отслеживание запуска и завершения Spotify;
- Apple Events через `NSAppleScript` или `ScriptingBridge` — чтение состояния и команды Spotify;
- `URLSession` — загрузка обложки, если Spotify предоставляет URL;
- `@AppStorage` — небольшие пользовательские настройки;
- Observation / `@Observable` — состояние приложения;
- `OSLog` / `Logger` — диагностические логи;
- `ServiceManagement` — запуск приложения при входе в систему.

## 7. Важный технический spike

До создания полноценного UI нужно проверить scripting dictionary установленного Spotify:

```bash
sdef /Applications/Spotify.app
```

Нужно подтвердить наличие команд и свойств:

- player state;
- current track;
- artist;
- album;
- duration;
- player position;
- artwork URL;
- sound volume;
- play/pause;
- next track;
- previous track.

После проверки выбрать один подход:

### Вариант A: `NSAppleScript`

Плюсы:

- быстро сделать прототип;
- не нужно генерировать дополнительные классы;
- удобно проверить идею.

Минусы:

- команды передаются строками;
- слабая типизация;
- сложнее поддерживать большое количество команд.

### Вариант B: `ScriptingBridge`

Плюсы:

- более структурированный и типизированный bridge;
- удобнее для долгосрочной поддержки.

Минусы:

- дополнительная генерация интерфейсов;
- больше начальной настройки;
- scripting dictionary Spotify может меняться.

Для первого spike лучше начать с `NSAppleScript`, а решение о миграции принять после рабочего прототипа.

## 8. Permissions

При первом управлении Spotify macOS может запросить разрешение на Automation / Apple Events.

Нужно:

- корректно обработать отказ;
- показать понятное сообщение;
- дать кнопку перехода к системным настройкам;
- не падать, если разрешение не выдано;
- отображать track state как unavailable.

Для локальной разработки App Sandbox можно сначала не включать. Перед распространением архитектуру permissions и entitlements нужно пересмотреть отдельно.

## 9. Архитектура

```text
TrackPeek/
├── App/
│   ├── TrackPeekApp.swift
│   └── AppDelegate.swift
├── Models/
│   ├── Track.swift
│   ├── PlaybackState.swift
│   └── PlayerStatus.swift
├── Stores/
│   ├── PlaybackStore.swift
│   └── PreferencesStore.swift
├── Services/
│   ├── MusicPlayerProvider.swift
│   ├── SpotifyAppleScriptClient.swift
│   ├── SpotifyApplicationMonitor.swift
│   └── ArtworkLoader.swift
├── Views/
│   ├── MenuBarLabel.swift
│   ├── PlayerPopoverView.swift
│   ├── TrackArtworkView.swift
│   ├── PlaybackControlsView.swift
│   ├── ProgressView.swift
│   ├── SpotifyUnavailableView.swift
│   └── SettingsView.swift
├── Support/
│   ├── DurationFormatter.swift
│   ├── TrackTitleFormatter.swift
│   └── AppLogger.swift
└── Tests/
    ├── TrackTitleFormatterTests.swift
    ├── DurationFormatterTests.swift
    └── PlaybackStoreTests.swift
```

## 10. Основные модели

```swift
struct Track: Equatable, Sendable {
    let id: String?
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval
    let artworkURL: URL?
}

enum PlayerStatus: Equatable, Sendable {
    case spotifyNotRunning
    case permissionDenied
    case stopped
    case paused
    case playing
    case unavailable(message: String)
}

struct PlaybackState: Equatable, Sendable {
    var status: PlayerStatus
    var track: Track?
    var position: TimeInterval
    var volume: Int?
    var updatedAt: Date
}
```

Источник playback-данных должен быть спрятан за протоколом:

```swift
protocol MusicPlayerProvider: Sendable {
    func fetchState() async throws -> PlaybackState
    func playPause() async throws
    func nextTrack() async throws
    func previousTrack() async throws
    func seek(to position: TimeInterval) async throws
    func setVolume(_ value: Int) async throws
    func openPlayer() async throws
}
```

Это позволит:

- использовать fake provider в SwiftUI previews;
- нормально тестировать UI;
- позже добавить Apple Music;
- заменить AppleScript на другой механизм без переписывания интерфейса.

## 11. Управление состоянием

`PlaybackStore` отвечает за:

- текущий `PlaybackState`;
- запуск и остановку polling;
- обновление позиции;
- команды пользователя;
- обработку ошибок;
- реакцию на запуск и завершение Spotify.

Предлагаемая частота:

- Spotify играет: обновление примерно раз в секунду;
- Spotify на паузе: раз в 3–5 секунд;
- Spotify закрыт: не опрашивать Apple Events, ждать событие `NSWorkspace`;
- popover закрыт: можно уменьшить частоту, если menu bar не показывает прогресс.

Важно не создавать новый AppleScript-процесс без необходимости на каждом кадре UI.

## 12. UI-направление

Интерфейс должен выглядеть как компактная нативная macOS-утилита:

- системные материалы;
- автоматическая светлая и тёмная тема;
- SF Symbols для стандартных действий;
- крупная обложка как основной визуальный элемент;
- минимум рамок;
- компактные отступы;
- нормальные hover- и pressed-состояния;
- управление мышью и клавиатурой;
- никаких мобильных tab bar и огромных touch-кнопок.

Пример popover:

```text
┌──────────────────────────────────┐
│  ┌────────┐  Jigsaw Falling...  │
│  │ cover  │  Radiohead           │
│  │        │  In Rainbows         │
│  └────────┘                       │
│                                  │
│  2:31  ━━━━━━━━━●━━━━━━  4:09    │
│                                  │
│        ◀︎       ▶︎       ▶︎▶︎     │
│                                  │
│  Open Spotify          Settings  │
└──────────────────────────────────┘
```

## 13. Этапы разработки

### Milestone 0 — Technical spike

- создать минимальное macOS-приложение;
- проверить `sdef` Spotify;
- получить название и исполнителя текущего трека;
- выполнить play/pause;
- проверить permission flow;
- записать найденные свойства Spotify в отдельный документ.

Критерий готовности:

> Приложение получает текущий трек и переключает play/pause без Spotify Web API.

### Milestone 1 — Menu bar MVP

- `MenuBarExtra`;
- иконка;
- название трека;
- состояния playing, paused и unavailable;
- базовый polling;
- открытие Spotify.

Критерий готовности:

> Текущий трек стабильно отображается в menu bar.

### Milestone 2 — Player popover

- обложка;
- метаданные;
- progress bar;
- previous/play-pause/next;
- обработка закрытого Spotify;
- loading и error states.

Критерий готовности:

> Основное управление Spotify возможно без перехода в его окно.

### Milestone 3 — Settings

- формат menu bar;
- максимальная длина;
- polling interval;
- login item;
- reset настроек;
- сохранение через `@AppStorage`.

### Milestone 4 — Polish

- клавиатурное управление;
- accessibility labels;
- качественные empty/error states;
- логирование;
- unit tests;
- тестирование после сна Mac;
- тестирование перезапуска Spotify;
- тестирование нескольких мониторов;
- иконка приложения;
- локальная Debug-сборка `.app`.

## 14. Возможные функции после MVP

### Track bookmarks

Сохранить текущий трек и позицию:

```text
Radiohead — Jigsaw Falling Into Place
Position: 2:31
Note: интересный переход
```

### Local listening history

- последние треки;
- время прослушивания;
- количество повторов;
- фильтр по исполнителю;
- локальное хранение без внешнего аккаунта.

### Global shortcuts

- play/pause;
- next;
- previous;
- показать popover;
- сохранить bookmark.

### Несколько плееров

После стабилизации Spotify-provider:

- Apple Music;
- YouTube Music в браузере — только если появится надёжный механизм;
- выбор активного player provider.

### Better menu bar modes

- бегущая строка;
- прогресс вокруг иконки;
- только обложка;
- скрытие текста на маленьком экране;
- автоматический режим в зависимости от свободного места.

## 15. Риски

### Spotify scripting dictionary

Spotify может изменить или удалить AppleScript-интерфейс. Поэтому:

- интеграция изолируется в одном service;
- UI не зависит от конкретного API;
- сначала выполняется technical spike;
- Web API рассматривается только как возможный fallback.

### Polling

Слишком частый AppleScript polling может быть неэффективным. Нужно измерить:

- CPU;
- wakeups;
- задержку обновления;
- поведение при закрытом Spotify.

### Artwork

URL обложки может отсутствовать или изменяться. UI должен иметь placeholder и не зависеть от успешной загрузки изображения.

### Permissions

Пользователь может отказаться от Automation permission. Приложение должно продолжать работать и объяснять, как включить разрешение.

## 16. Definition of Done для версии 0.1

Версия 0.1 считается законченной, когда:

- приложение работает из menu bar;
- корректно определяет, запущен ли Spotify;
- показывает текущий трек и исполнителя;
- показывает playing/paused;
- умеет play/pause, previous и next;
- имеет компактный popover;
- не требует Spotify Web API;
- корректно переживает закрытие и повторный запуск Spotify;
- сохраняет пользовательские настройки;
- не создаёт файлы или данные без необходимости;
- собирается командой из терминала;
- содержит минимальные unit tests;
- имеет README с инструкцией запуска.

## 17. Команды разработки

Проверить Swift:

```bash
swift --version
```

Собрать проект:

```bash
xcodebuild   -project TrackPeek.xcodeproj   -scheme TrackPeek   -configuration Debug   build
```

Запустить unit tests:

```bash
xcodebuild   -project TrackPeek.xcodeproj   -scheme TrackPeek   -destination 'platform=macOS'   test
```

Основной код можно писать в VS Code. Полный Xcode должен быть установлен для macOS SDK, сборки приложения, signing и настройки target/entitlements.

## 18. Официальные reference points

- Apple SwiftUI `MenuBarExtra`
- Apple AppKit `NSWorkspace`
- Apple Scripting Bridge
- Apple Event automation permissions
- Apple ServiceManagement login items
- Swift.org getting started and Swift Package Manager

Ссылки:

- https://developer.apple.com/documentation/swiftui/menubarextra
- https://developer.apple.com/documentation/appkit/nsworkspace
- https://developer.apple.com/documentation/scriptingbridge
- https://developer.apple.com/documentation/servicemanagement
- https://www.swift.org/getting-started/
