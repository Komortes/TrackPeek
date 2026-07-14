import AppKit
import SwiftUI

/// The action list shared by the "…" menu button and every right-click context
/// menu, so all surfaces (popover, notch) expose the same actions consistently.
struct PlayerActionsMenuItems: View {
    let track: SpotifyTrack?
    let onRefresh: () -> Void

    var body: some View {
        Group {
            Button("Открыть Spotify", systemImage: "arrow.up.right.square") {
                openSpotify()
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

            SettingsLink {
                Label("Настройки…", systemImage: "gearshape")
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

    private func openSpotify() {
        guard let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.spotify.client"
        ) else {
            return
        }

        NSWorkspace.shared.openApplication(
            at: url,
            configuration: NSWorkspace.OpenConfiguration()
        )
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
