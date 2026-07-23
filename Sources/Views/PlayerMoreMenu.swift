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
    let onRefresh: () -> Void

    @Environment(\.openSettings) private var openSettings
    @AppStorage(MediaSourcePreference.storageKey)
    private var sourceRawValue = MediaSourcePreference.fallback.rawValue

    private var sourceName: String {
        (MediaSourcePreference(rawValue: sourceRawValue) ?? .fallback) == .appleMusic
            ? "Music"
            : "Spotify"
    }

    var body: some View {
        Group {
            Button("Открыть \(sourceName)", systemImage: "arrow.up.right.square") {
                PlayerAppLauncher.openActiveSource()
            }

            Divider()

            Button("Копировать название", systemImage: "doc.on.doc") {
                copy(track?.title ?? "")
            }
            .disabled(track == nil)

            Button("Копировать исполнителя и трек", systemImage: "text.quote") {
                guard let track else { return }
                copy("\(track.artist) — \(track.title)")
            }
            .disabled(track == nil)

            Button("Обновить", systemImage: "arrow.clockwise", action: onRefresh)

            Divider()

            Button("Настройки…", systemImage: "gearshape") {
                SettingsWindowPresentation.present(openSettings: openSettings.callAsFunction)
            }

            Button("Завершить TrackPeek", systemImage: "power") {
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
    let onRefresh: () -> Void

    var body: some View {
        Menu {
            PlayerActionsMenuItems(track: track, onRefresh: onRefresh)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Дополнительные действия")
        .accessibilityLabel("Дополнительные действия")
    }
}

/// Attaches the same right-click actions as `PlayerMoreMenu` directly to a
/// surface, so users don't have to hunt for the small "…" button.
struct PlayerContextMenuModifier: ViewModifier {
    let track: SpotifyTrack?
    let onRefresh: () -> Void

    func body(content: Content) -> some View {
        content.contextMenu {
            PlayerActionsMenuItems(track: track, onRefresh: onRefresh)
        }
    }
}

extension View {
    func playerContextMenu(track: SpotifyTrack?, onRefresh: @escaping () -> Void) -> some View {
        modifier(PlayerContextMenuModifier(track: track, onRefresh: onRefresh))
    }
}
