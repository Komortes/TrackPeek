import SwiftUI

/// Панель текста песни в раскрытой чёлке/виджете: текущая + следующая строка,
/// синхронизированные с позицией воспроизведения.
struct NotchLyricsView: View {
    let state: LyricsStore.State
    let position: TimeInterval
    let duration: TimeInterval
    let isPlaying: Bool
    let snapshotDate: Date
    var tint: Color = .white

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch state {
            case .loading:
                placeholder("Ищем текст…", systemImage: "ellipsis")
            case .unavailable:
                placeholder("Текст не найден", systemImage: "quote.bubble")
            case .loaded(let lyrics):
                if lyrics.isSynced {
                    syncedLyrics(lyrics.syncedLines)
                } else if let plain = lyrics.plainText {
                    plainLyrics(plain)
                } else {
                    placeholder("Текст не найден", systemImage: "quote.bubble")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func placeholder(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .semibold))

            Text(text)
                .font(.system(size: 10, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
    }

    private func syncedLyrics(_ lines: [LyricsLine]) -> some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let livePosition = PlaybackPositionResolver.livePosition(
                snapshotPosition: position,
                snapshotDate: snapshotDate,
                now: context.date,
                duration: duration,
                isPlaying: isPlaying
            )
            let index = TrackLyrics.currentIndex(in: lines, position: livePosition)
            let current = index.map { lines[$0].text }
            let next = index.flatMap { $0 + 1 < lines.count ? lines[$0 + 1].text : nil }
                ?? (index == nil ? lines.first?.text : nil)

            VStack(alignment: .leading, spacing: 3) {
                Text(current ?? "…")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(current == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(tint))
                    .lineLimit(1)
                    .id(current)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .push(from: .bottom).combined(with: .opacity)
                    )

                Text(next ?? " ")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .animation(
                reduceMotion ? nil : .smooth(duration: 0.3, extraBounce: 0),
                value: current
            )
            .frame(minHeight: 30, alignment: .leading)
        }
    }

    private func plainLyrics(_ text: String) -> some View {
        ScrollView(showsIndicators: false) {
            Text(text)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 30)
    }
}
