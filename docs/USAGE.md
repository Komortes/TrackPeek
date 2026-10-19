# Using TrackPeek

Detailed behavior for TrackPeek 1.1 (build 3), including the updated Settings window. See the [README](../README.md) for installation and [release notes](releases/1.1.md) for changes since 1.0. UI labels are currently in Russian; English descriptions below include their matching labels.

## Displays and placement

- **Named monitor:** stays selected across reconnections. If disconnected, the panel temporarily uses the primary display and returns when the selected monitor reconnects.
- **Automatic:** the widget prefers an external display; the notch surface appears only on a display with a physical notch.
- **Primary / Notched / All displays:** the existing placement policies remain available.
- **Free movement:** enable it in Widget settings to drag ordinary widgets by their background. Moving a single widget to another monitor saves that destination. Edge uses the monitor and left/right selectors instead of free dragging.

See [display selection details](product/display-selection.md) for behavior and verification notes.

## Settings organization

The settings sidebar separates General, Notch, Widget, Menu Bar, Shortcuts, Resources, and About. General follows **music source → screen panel → visibility**, with launch at login in its own section.

Widget settings group **Template / Placement / Appearance**. All four template categories are visible; browsing a category leaves the selected template unchanged. Placement starts with the monitor, followed by the position and free-movement options. Position locking and reset appear when free movement is enabled.

Appearance shows controls that apply to the selected template. **Replace progress with lyrics** is available for Pill, Side artwork and Top artwork (`Пилюля / Обложка сбоку / Обложка сверху`); the dedicated lyrics templates show text without that switch. Templates with no lyrics do not start a lookup from its saved value. Progress color appears where there is a progress bar or colored lyric text. Wave color and sensitivity appear where there is an equalizer. Top artwork, Lyrics and Karaoke offer **Colored background** (`Цветной фон`) for the palette gradient; Artwork Square omits background options hidden behind its cover. Wave color is independent of progress color. Choices stay saved when you switch templates.

Notch settings separate **Appearance / Behavior** (`Оформление / Поведение`), while Menu Bar separates **Indicators and buttons / Player window** (`Индикаторы и кнопки / Окно плеера`). Optional visual effects and general presets expand on demand. Existing preferences and direct links from player menus are preserved.

Right-click the player or use its **…** menu for quick actions. **Copy** (`Копировать`) groups the title and artist/title options; **Player appearance** (`Вид плеера`) groups overlay modes and, when a widget is active, its templates. Lyrics, temporary hiding, refresh, and settings remain directly accessible.

Use **Source** (`Источник`) to choose Spotify, Apple Music, or Automatic without opening Settings. Both controls share the same saved preference. Changing it refreshes the player and clears the previous source's track and lyrics; it does not launch a closed music app or start playback. Automatic prefers a playing source, then the last active source when possible. **Open** follows the source currently displayed in Automatic mode.

In Automatic mode, a player without a selected song does not hide a paused song in the other running app. Each candidate is read once per refresh.

The launch-at-login switch reflects the system's registration. If macOS requires approval, it stays selected and shows how to open Login Items. Failed changes show feedback and restore the system's actual state; returning from System Settings refreshes the switch.

## Focus notch and Lyrics popover

- **Settings → Notch → Appearance → Layout → Focus** (`Чёлка → Оформление → Раскладка → Фокус`) selects the restrained notch layout. Its collapsed title avoids the camera gap on notched displays, and expanded controls sit below the safe top area. Width and height correction remain adjustable; the full player's effect settings are preserved.
- **Settings → Menu Bar → Player window → Lyrics** (`Строка меню → Окно плеера → Текст`) opens a fixed-size reading panel. Synchronized lyrics show the whole song with the current line highlighted. Click a lyric to seek to it, including the current timing adjustment; a paused track stays paused. Scroll to read another verse: automatic following pauses until you select **Back to current line** (`К текущей строке`). Changing the song/source or reopening the panel restores following. Plain text remains manually scrollable and selectable, without line seeking. Missing lyrics and network failures have separate states and a retry action. Playback and seeking remain at the bottom.

Both layouts retain the existing menus and playback source. Lyrics uses the shared store, a neutral system background, and no artwork. Its lyric schedule and progress updates stop when the view closes; Focus creates its progress view only while expanded. Neither layout changes widget selection or overwrites other layouts' appearance choices.

## Lyric Strip widget

Choose **Settings → Widget → Template → Lyrics → Lyric Strip** (`Виджет → Шаблон → Текст песни → Строка текста`). Its width is adjustable from 320 to 500 pt; its height stays at 56 pt. Use the existing placement controls to put it near the bottom of your chosen monitor or enable free movement.

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

Player controls also support local keyboard navigation. Click the progress bar to focus the player, then use **Left/Right** to seek by five seconds; a paused song stays paused. **Tab** moves between progress and volume where available. On the volume slider, arrows change the volume by one percent. Each control shows its focus; combinations with Command, Control, Option, or Shift remain available to the app and system. Caps Lock does not block these controls or Lyric Strip keys.

Interactive artwork is a labeled **Open Spotify / Music** button in player and widget layouts, available to VoiceOver and standard macOS keyboard navigation. The compact notch exposes the full title, artist, and playback state before expanding; hovering also shows the full metadata.

## Resource usage

Choose **Settings → Resources** (`Ресурсы`). **Automatic** is the default and follows macOS Low Power Mode, including changes while TrackPeek is running. Battery power alone does not activate it. On Macs where the system mode is unsupported, Automatic behaves like Normal; Economical remains available manually.

**Economical** keeps the equalizer static, stops audio capture, pulse effects and shimmering borders, and updates playback progress once a second. Healthy playback polls change from 2 to 5 seconds while playing and from 4 to 8 seconds while paused. External track changes can therefore take up to five seconds to appear. Clicks, seeking, global shortcuts and manual refresh still run immediately; connection recovery retains its existing backoff.

Appearance settings are preserved and restored when economy ends, subject to Reduce Motion and existing visibility rules. Synchronized lyrics retain their timing; this mode does not disable lyrics loading or change the bounded artwork/lyrics caches. The Resources section shows whether economy is currently active; Diagnostics explains when audio analysis is stopped for economy.

The collapsed notch pauses the hidden expanded player's progress and lyric clocks. Expanding resumes from the current playback position; the collapse transition preserves its last displayed position. The visible equalizer and existing polling policy continue to follow their own settings.

Artwork keeps its current image while a different resolution of the same cover loads. A new track clears the previous cover immediately. Loading indicators appear only after a short delay and stay static in small artwork slots, Reduce Motion, and Economical mode; missing or failed artwork uses a sized music-note placeholder.

The audio-analysis status reports **Running** only after a valid audio buffer has arrived. If valid buffers stop for three seconds, TrackPeek recreates the capture with delays of 2, 4, 8, 16, then at most 30 seconds. Silent buffers are healthy; silence alone does not trigger reconnects. **Resources → Diagnostics** shows connection, player access and audio-analysis status, with a manual retry after a capture failure. Last and next check times expand under **Connection details** (`Подробности подключения`); refresh and report-copy actions remain visible.

## Privacy and network use

Playback state and commands use local **AppleScript / Apple Events**. TrackPeek does not require a separate Spotify or Apple Music web login.

Some features use the network:

- Lyrics requests send the track title, artist, duration, and album (when available) to **LRCLIB**.
- Remote artwork is loaded from the URL supplied by the player. Apple Music artwork is read from the local app and written to a temporary file.
- Sparkle checks the configured GitHub release feed and downloads updates.

TrackPeek does not keep a listening-history database. Artwork data, decoded images, palettes, and lyrics use bounded in-memory caches. Artwork downloads share an ephemeral session without an additional HTTP cache. Diagnostic reports are copied only on request and exclude song metadata, user paths, and raw error messages.

If Automation access is denied, automatic polling stops until you retry or a relevant lifecycle event occurs. Open **Settings → Resources → Diagnostics** to reach macOS permissions and check again.

Playback scripts run in a bundled, signed helper process. A timeout or cancellation of an active request terminates the helper and discards its pending commands; a new request can start a fresh process. Playback commands are never automatically replayed, because a player may already have performed them before the timeout. The helper is reused between requests, waits without a polling timer, and exits with TrackPeek. The initial macOS Automation consent prompt has a separate, longer deadline.
