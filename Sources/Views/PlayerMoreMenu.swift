import AppKit
import SwiftUI

@MainActor
enum SettingsWindowPresentation {
    static func present(
        openSettings: () -> Void,
        focusSettingsWindow: @escaping @MainActor () -> Void = focusLiveSettingsWindow
    ) {
        openSettings()
        RunLoop.main.perform(inModes: [.default]) {
            MainActor.assumeIsolated {
                focusSettingsWindow()
            }
        }
    }

    static func isSettingsWindow(_ window: NSWindow) -> Bool {
        !(window is NSPanel)
            && window.level == .normal
            && window.styleMask.contains(.titled)
            && window.canBecomeKey
    }

    private static func focusLiveSettingsWindow() {
        NSApplication.shared.activate()
        let settingsWindow = NSApplication.shared.windows.first {
            isSettingsWindow($0)
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

/// The action list shared by the "…" menu button and every right-click context
/// menu, so all surfaces (popover, notch) expose the same actions consistently.
struct PlayerActionsMenuItems: View {
    let track: SpotifyTrack?
    let sourceName: String
    let onRefresh: () -> Void

    @Environment(\.openSettings) private var openSettings

    @AppStorage(MediaSourcePreference.storageKey)
    private var mediaSourceRawValue = MediaSourcePreference.fallback.rawValue
    @AppStorage(OverlayMode.storageKey)
    private var overlayModeRawValue = OverlayMode.fallback.rawValue
    @AppStorage(WidgetPreferences.layoutKey)
    private var widgetLayoutRawValue = NotchWidgetLayout.fallback.rawValue
    @AppStorage(OverlayVisibility.temporarilyHiddenKey)
    private var temporarilyHidden = false
    @AppStorage(SettingsTab.selectionStorageKey)
    private var selectedSettingsTab = SettingsTab.general.rawValue

    private var mediaSource: Binding<MediaSourcePreference> {
        Binding(
            get: { MediaSourcePreference(rawValue: mediaSourceRawValue) ?? .fallback },
            set: { mediaSourceRawValue = $0.rawValue }
        )
    }

    var body: some View {
        Group {
            Button(String(localized: "Open \(sourceName)"), systemImage: "arrow.up.right.square") {
                PlayerAppLauncher.openActiveSource()
            }

            Menu(String(localized: "Source"), systemImage: "music.note.list") {
                Picker(String(localized: "Track Source"), selection: mediaSource) {
                    ForEach(MediaSourcePreference.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }
                .pickerStyle(.inline)
            }

            if let track {
                LyricsActionsMenu(track: track, store: PlaybackCoordinator.shared.lyricsStore)
                    .disabled(PlaybackCoordinator.shared.model.isStale)
            }

            Menu(String(localized: "Copy"), systemImage: "doc.on.doc") {
                Button(String(localized: "Title")) {
                    copy(track?.title ?? "")
                }

                Button(String(localized: "Artist and Track")) {
                    guard let track else { return }
                    copy("\(track.artist) — \(track.title)")
                }
            }
            .disabled(track == nil)

            Divider()

            Menu(String(localized: "Player Appearance"), systemImage: "rectangle.on.rectangle") {
                Picker(String(localized: "On-Screen Player"), selection: $overlayModeRawValue) {
                    ForEach(OverlayMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.inline)

                if OverlayMode(rawValue: overlayModeRawValue) == .floatingWidget {
                    Divider()

                    Menu(String(localized: "Widget Template")) {
                        Picker(String(localized: "Widget Template"), selection: $widgetLayoutRawValue) {
                            ForEach(NotchWidgetLayout.allCases) { layout in
                                Text(layout.title).tag(layout.rawValue)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                }
            }

            if OverlayMode(rawValue: overlayModeRawValue) != .off {
                Button(
                    temporarilyHidden ? String(localized: "Show Panel") : String(localized: "Hide Temporarily"),
                    systemImage: temporarilyHidden ? "eye" : "eye.slash"
                ) {
                    temporarilyHidden.toggle()
                }
            }

            Divider()

            Button(String(localized: "Refresh"), systemImage: "arrow.clockwise", action: onRefresh)

            Button(String(localized: "Settings…"), systemImage: "gearshape") {
                selectedSettingsTab = switch OverlayMode(rawValue: overlayModeRawValue) {
                case .notch: SettingsTab.notch.rawValue
                case .floatingWidget: SettingsTab.widget.rawValue
                default: SettingsTab.general.rawValue
                }
                SettingsWindowPresentation.present(openSettings: openSettings.callAsFunction)
            }

            Button(String(localized: "Quit TrackPeek"), systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

struct PlayerMoreMenu: View {
    let track: SpotifyTrack?
    let sourceName: String
    let onRefresh: () -> Void

    var body: some View {
        Menu {
            PlayerActionsMenuItems(track: track, sourceName: sourceName, onRefresh: onRefresh)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(String(localized: "More Actions"))
        .accessibilityLabel(String(localized: "More Actions"))
    }
}

/// Attaches the same right-click actions as `PlayerMoreMenu` directly to a
/// surface, so users don't have to hunt for the small "…" button.
struct PlayerContextMenuModifier: ViewModifier {
    let track: SpotifyTrack?
    let sourceName: String
    let onRefresh: () -> Void

    func body(content: Content) -> some View {
        content.contextMenu {
            PlayerActionsMenuItems(track: track, sourceName: sourceName, onRefresh: onRefresh)
        }
    }
}

extension View {
    func playerContextMenu(
        track: SpotifyTrack?,
        sourceName: String,
        onRefresh: @escaping () -> Void
    ) -> some View {
        modifier(PlayerContextMenuModifier(track: track, sourceName: sourceName, onRefresh: onRefresh))
    }
}
