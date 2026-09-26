import SwiftUI

/// View-local reading intent survives polling, pause and seek. The parent
/// recreates this view only when the song/source changes, not at every lyric.
struct SyncedLyricsReader: View {
    let lines: [LyricsLine]
    let position: TimeInterval
    let snapshotDate: Date
    let duration: TimeInterval
    let isPlaying: Bool
    let isVisible: Bool
    let isStale: Bool
    let offset: TimeInterval
    let onSeek: (TimeInterval) -> Void
    @State private var isFollowing = true

    var body: some View {
        let now = Date()
        let dates = LyricStripTimeline.dates(lines: lines, position: position, snapshotDate: snapshotDate,
            duration: duration, isPlaying: isPlaying, isVisible: isVisible, isStale: isStale, now: now, offset: offset)
        // Keep the same tree while paused or hidden: branching around TimelineView
        // would recreate the scroll position and undo manual reading intent.
        TimelineView(.explicit(dates.isEmpty ? [now] : dates)) { timeline in
            let livePosition = PlaybackPositionResolver.livePosition(snapshotPosition: position,
                snapshotDate: snapshotDate, now: timeline.date, duration: duration,
                isPlaying: isPlaying && isVisible && !isStale) + offset
            let current = TrackLyrics.currentIndex(in: lines, position: livePosition)
            let target = LyricsReaderNavigation.currentScrollIndex(in: lines, position: livePosition)
            ScrollViewReader { proxy in
                VStack(spacing: 6) {
                    ScrollView {
                        // The probe belongs to a stable container, never a lazy row
                        // which might disappear as the reader moves through the song.
                        VStack(spacing: 0) {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(lines.indices, id: \.self) { index in
                                    LyricsReaderRow(line: lines[index], isCurrent: index == current,
                                        seekPosition: LyricsReaderNavigation.seekPosition(for: lines[index], duration: duration, offset: offset),
                                        onSeek: onSeek)
                                        .id(index)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 3)
                        }
                        .background {
                            LyricsScrollInteraction { isFollowing = false }
                                .frame(width: 0, height: 0)
                        }
                    }
                    .focusable()
                    .onKeyPress(keys: [.upArrow, .downArrow, .pageUp, .pageDown, .home, .end, .space], phases: .down) { press in
                        guard !press.modifiers.contains(.command), !press.modifiers.contains(.control) else { return .ignored }
                        isFollowing = false
                        return .ignored
                    }
                    .accessibilityLabel("Полный текст песни")
                    footer {
                        isFollowing = true
                        scroll(to: target, with: proxy)
                    }
                }
                .onChange(of: target, initial: true) { _, target in
                    if isFollowing { scroll(to: target, with: proxy) }
                }
                .onChange(of: isVisible) { _, visible in
                    if visible {
                        isFollowing = true
                        scroll(to: target, with: proxy)
                    }
                }
            }
        }
    }

    private func scroll(to index: Int?, with proxy: ScrollViewProxy) {
        guard isVisible, let index else { return }
        // Immediate jumps cannot keep animating against a newly started gesture.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { proxy.scrollTo(index, anchor: .center) }
    }

    private func footer(onResume: @escaping () -> Void) -> some View {
        Group {
            if isFollowing {
                Text("Нажмите строку для перемотки")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            } else {
                Button("К текущей строке", systemImage: "location.fill", action: onResume)
                    .buttonStyle(.borderless).font(.system(size: 11, weight: .medium))
                    .help("Вернуться к текущей строке и включить автопрокрутку")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 26, maxHeight: 26)
    }
}

struct LyricsReaderRow: View {
    let line: LyricsLine
    let isCurrent: Bool
    let seekPosition: TimeInterval?
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        if let seekPosition {
            Button { onSeek(seekPosition) } label: { label }
                .buttonStyle(.plain)
                .help("Перейти к \(PlaybackTimeFormatter.string(from: seekPosition))")
                .accessibilityLabel(line.text)
                .accessibilityValue("\(isCurrent ? "Текущая строка, " : "")\(PlaybackTimeFormatter.string(from: seekPosition))")
                .accessibilityHint("Перемотать к этой строке")
        } else {
            label
        }
    }

    private var label: some View {
        Text(line.text.isEmpty ? "Проигрыш" : line.text)
            // Highlight changes neither type size nor weight, keeping row geometry
            // stable while the user reads elsewhere in the song.
            .font(.system(size: line.text.isEmpty ? 13 : 16, weight: .medium))
            .foregroundStyle(isCurrent && !line.text.isEmpty ? Color.primary : Color.secondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(isCurrent ? Color.accentColor.opacity(0.12) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 9))
            .contentShape(Rectangle())
    }
}
