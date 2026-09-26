import SwiftUI

struct LyricsPlayerView: View {
    let model: SpotifySpikeModel
    let track: SpotifyTrack
    let lyricsStore: LyricsStore
    let options: PlayerPresentationOptions
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 10) {
            PlayerHeaderView(track: track, sourceName: model.activeSourceDisplayName,
                showsPlaybackStatus: options.showsPlaybackStatus, onRefresh: { Task { await model.refresh() } })
            TrackInfoView(track: track, showsAlbum: options.showsAlbum, titleLineLimit: 1)
                .frame(maxWidth: .infinity, alignment: .leading)
            readingArea.frame(maxWidth: .infinity, maxHeight: .infinity)
            PlaybackProgressView(position: track.position, duration: track.duration,
                isPlaying: track.isPlaying && isVisible && !model.isStale, snapshotDate: model.snapshotDate,
                onSeek: { position in Task { await model.seek(to: position) } }, minimumUpdateInterval: 0.25)
            PlaybackControlsView(isPlaying: track.isPlaying,
                onPrevious: { Task { await model.previousTrack() } },
                onPlayPause: { Task { await model.togglePlayback() } },
                onNext: { Task { await model.nextTrack() } }, spacing: 24)
        }
        .padding(16)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .task(id: RequestKey(request: LyricsRequest(track: track), visible: isVisible)) {
            guard isVisible else { return }
            lyricsStore.prepare(for: track)
        }
    }

    private struct RequestKey: Equatable {
        let request: LyricsRequest
        let visible: Bool
    }

    @ViewBuilder private var readingArea: some View {
        switch lyricsStore.state(for: track) {
        case .loading:
            placeholder("Ищем текст…", symbol: "text.quote")
        case .unavailable, .failed:
            VStack(spacing: 12) {
                placeholder(lyricsStore.state(for: track) == .unavailable ? "Текст не найден" : "Не удалось загрузить текст", symbol: "quote.bubble")
                Button("Повторить поиск") { lyricsStore.retry(for: track) }.buttonStyle(.bordered)
            }
        case .loaded(let lyrics):
            if lyrics.isSynced {
                SyncedLyricsReader(lines: lyrics.syncedLines, position: track.position,
                    snapshotDate: model.snapshotDate, duration: track.duration,
                    isPlaying: track.isPlaying, isVisible: isVisible, isStale: model.isStale,
                    offset: lyricsStore.offset(for: track),
                    onSeek: { position in Task { await model.seek(to: position) } })
                    .id(ReaderIdentity(request: LyricsRequest(track: track), source: track.source))
            } else if let plain = lyrics.plainText, !plain.isEmpty {
                ScrollView {
                    Text(plain).font(.system(size: 15)).lineSpacing(6)
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(LyricsRequest(track: track))
            } else {
                placeholder("Текст не найден", symbol: "quote.bubble")
            }
        }
    }

    private struct ReaderIdentity: Hashable {
        let request: LyricsRequest
        let source: PlaybackSource?
    }

    private func placeholder(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.system(size: 13)).foregroundStyle(.secondary)
            .multilineTextAlignment(.center).frame(maxWidth: .infinity)
    }
}
