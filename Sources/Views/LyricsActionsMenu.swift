import SwiftUI

/// Rare lyrics actions live in the existing menu, not as permanent player controls.
struct LyricsActionsMenu: View {
    let track: SpotifyTrack
    let store: LyricsStore

    private var offset: TimeInterval { store.offset(for: track) }
    private var offsetLabel: String {
        guard offset != 0 else { return "Без поправки" }
        let seconds = abs(offset).formatted(.number.precision(.fractionLength(1)))
        return offset > 0 ? "На \(seconds) с раньше" : "На \(seconds) с позже"
    }

    var body: some View {
        Menu("Текст песни") {
            switch store.state(for: track) {
            case .loaded(let lyrics):
                if lyrics.isSynced {
                    Text(offsetLabel)
                    Button("Раньше на 0,5 с") { store.setOffset(offset + 0.5, for: track) }
                        .disabled(offset >= 10)
                    Button("Позже на 0,5 с") { store.setOffset(offset - 0.5, for: track) }
                        .disabled(offset <= -10)
                    Button("Сбросить поправку") { store.setOffset(0, for: track) }
                        .disabled(offset == 0)
                    Divider()
                    Text("Только для текущей песни")
                } else {
                    Text("Текст без синхронизации")
                }
            case .failed, .unavailable:
                Button("Повторить поиск") { store.retry(for: track) }
            case .loading:
                Button(store.isLoading(for: track) ? "Ищем текст…" : "Найти текст") {
                    store.prepare(for: track)
                }
                .disabled(store.isLoading(for: track))
            }
        }
    }
}
