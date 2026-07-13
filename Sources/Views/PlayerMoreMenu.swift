import AppKit
import SwiftUI

struct PlayerMoreMenu: View {
    let track: SpotifyTrack?
    let onRefresh: () -> Void

    var body: some View {
        Menu {
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
