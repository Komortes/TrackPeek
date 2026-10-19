import SwiftUI

/// Rare lyrics actions live in the existing menu, not as permanent player controls.
struct LyricsActionsMenu: View {
    let track: SpotifyTrack
    let store: LyricsStore

    private var offset: TimeInterval { store.offset(for: track) }
    private var offsetLabel: String {
        guard offset != 0 else { return String(localized: "No adjustment") }
        let seconds = abs(offset).formatted(.number.precision(.fractionLength(1)))
        return offset > 0 ? String(localized: "\(seconds) s earlier") : String(localized: "\(seconds) s later")
    }

    var body: some View {
        Menu(String(localized: "Song Lyrics")) {
            switch store.state(for: track) {
            case .loaded(let lyrics):
                if lyrics.isSynced {
                    Text(offsetLabel)
                    Button(String(localized: "0.5 s Earlier")) { store.setOffset(offset + 0.5, for: track) }
                        .disabled(offset >= 10)
                    Button(String(localized: "0.5 s Later")) { store.setOffset(offset - 0.5, for: track) }
                        .disabled(offset <= -10)
                    Button(String(localized: "Reset Timing")) { store.setOffset(0, for: track) }
                        .disabled(offset == 0)
                    Divider()
                    Text(String(localized: "For this song only"))
                } else {
                    Text(String(localized: "Unsynchronized lyrics"))
                }
            case .failed, .unavailable:
                Button(String(localized: "Search Again")) { store.retry(for: track) }
            case .loading:
                Button(store.isLoading(for: track) ? String(localized: "Finding lyrics…") : String(localized: "Find Lyrics")) {
                    store.prepare(for: track)
                }
                .disabled(store.isLoading(for: track))
            }
        }
    }
}
