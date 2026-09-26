import AppKit
import Observation
import SwiftUI
import Testing
@testable import TrackPeek

@MainActor
@Suite("Hosted full lyrics reader", .serialized, .timeLimit(.minutes(1)))
struct SyncedLyricsReaderTests {
    @Test("follows the current line, preserves manual reading through playback changes, and resumes")
    func readingAndFollowingInNativeScrollView() async throws {
        let playback = ReaderPlaybackFixture()
        let host = NSHostingView(rootView: ReaderFixtureView(playback: playback))
        let window = NSWindow(contentRect: NSRect(x: 40, y: 40, width: 380, height: 360),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = "TrackPeek — lyrics integration fixture"
        window.contentView = host
        // Mount the real AppKit hierarchy without making this window key/front.
        window.orderBack(nil)
        defer {
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }

        let mounted = await settle(host) { descendant(of: NSScrollView.self, in: host) != nil }
        #expect(mounted)
        let scroll = try #require(descendant(of: NSScrollView.self, in: host))
        let observer = try #require(descendant(of: LyricsScrollObserverView.self, in: host))
        #expect(observer.enclosingScrollView === scroll,
            "The production interaction probe must belong to the actual SwiftUI scroller")
        let initiallyFollowed = await settle(host) { scroll.contentView.bounds.minY > 150 }
        #expect(initiallyFollowed, "Opening in the middle of a song should reveal its current row")
        #expect(returnButton(in: host) == nil, "Initial scrollTo must not disable following")

        let firstOrigin = scroll.contentView.bounds.minY
        playback.update(position: 251, isPlaying: false)
        let followedNextPosition = await settle(host) { scroll.contentView.bounds.minY > firstOrigin + 150 }
        #expect(followedNextPosition, "A later current row should cause another automatic scroll")
        #expect(returnButton(in: host) == nil, "Programmatic scrolling must keep following enabled")

        await settleLayout(host)
        let currentObserver = try #require(descendant(of: LyricsScrollObserverView.self, in: host))
        #expect(currentObserver.enclosingScrollView === scroll)
        // Emit the same public AppKit notification the native scroll observer
        // receives for trackpad/scroller input, then move the native clip view.
        NotificationCenter.default.post(name: NSScrollView.willStartLiveScrollNotification, object: scroll)
        scroll.contentView.scroll(to: .zero)
        scroll.reflectScrolledClipView(scroll.contentView)
        let manuallyReading = await settle(host) { returnButton(in: host) != nil }
        #expect(manuallyReading)
        try saveSnapshot(host)
        let manualOrigin = scroll.contentView.bounds.minY

        playback.update(position: 291, isPlaying: true)
        await settleLayout(host)
        #expect(abs(scroll.contentView.bounds.minY - manualOrigin) < 2,
            "Position changes must not pull a manually scrolled reader back to the current line")
        #expect(returnButton(in: host) != nil)

        playback.update(position: 301, isPlaying: false)
        await settleLayout(host)
        #expect(abs(scroll.contentView.bounds.minY - manualOrigin) < 2,
            "Pausing must preserve the reader tree and manual scroll position")
        let resume = try #require(returnButton(in: host))
        // The borderless footer is a native NSButton. Invoke its real action;
        // the non-front NSHostingView does not publish a complete AX child tree.
        resume.performClick(nil)
        let resumed = await settle(host) {
            returnButton(in: host) == nil && scroll.contentView.bounds.minY > manualOrigin + 150
        }
        #expect(resumed, "The return button must reveal the current row and restore following")

        let resumedOrigin = scroll.contentView.bounds.minY
        playback.update(position: 201, isPlaying: false)
        let followedAfterResume = await settle(host) { scroll.contentView.bounds.minY < resumedOrigin - 150 }
        #expect(followedAfterResume)
        #expect(returnButton(in: host) == nil)

        NotificationCenter.default.post(name: NSScrollView.didLiveScrollNotification, object: scroll)
        scroll.contentView.scroll(to: .zero)
        scroll.reflectScrolledClipView(scroll.contentView)
        let readingAgain = await settle(host) { returnButton(in: host) != nil }
        #expect(readingAgain)
        // Mirror LyricsPlayerView's song/source identity boundary: ordinary
        // polling keeps state, but selecting a new source creates a fresh reader.
        playback.source = .appleMusic
        let resetForSource = await settle(host) {
            returnButton(in: host) == nil &&
                (descendant(of: NSScrollView.self, in: host)?.contentView.bounds.minY ?? 0) > 150
        }
        #expect(resetForSource, "A new reader identity must restore automatic following")

        try saveSnapshot(host)
    }

    private func saveSnapshot(_ host: NSView) throws {
        host.displayIfNeeded()
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: "/tmp/trackpeek-full-lyrics-reader.png"))
    }

    private func descendant<T: NSView>(of type: T.Type, in view: NSView) -> T? {
        if let match = view as? T { return match }
        for child in view.subviews {
            if let match = descendant(of: type, in: child) { return match }
        }
        return nil
    }

    private func settle(_ host: NSView, until condition: () -> Bool) async -> Bool {
        for _ in 0..<200 {
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
            if condition() { return true }
            await nextMainLoopTurn()
        }
        return condition()
    }

    private func settleLayout(_ host: NSView) async {
        // Drain a bounded number of actual layout/main-queue passes, not a delay
        // chosen to match animation timing (the reader intentionally does not animate).
        for _ in 0..<20 {
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
            await nextMainLoopTurn()
        }
    }

    private func nextMainLoopTurn() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                RunLoop.main.perform(inModes: [.default]) { continuation.resume() }
            }
        }
    }

    private func returnButton(in host: NSView) -> NSButton? {
        // Lyric rows use SwiftUI's plain style; only the return footer creates
        // an AppKit button. Assert its absence during automatic following too.
        descendant(of: NSButton.self, in: host)
    }

}

@MainActor
@Observable
private final class ReaderPlaybackFixture {
    var position: TimeInterval = 151
    var snapshotDate = Date()
    var isPlaying = false
    var source: PlaybackSource = .spotify

    func update(position: TimeInterval, isPlaying: Bool) {
        self.position = position
        snapshotDate = Date()
        self.isPlaying = isPlaying
    }
}

private struct ReaderFixtureView: View {
    let playback: ReaderPlaybackFixture
    private let lines = (0..<40).map { index in
        LyricsLine(time: Double(index * 10), text: "Строка \(index + 1) — музыка остаётся с нами")
    }

    var body: some View {
        SyncedLyricsReader(lines: lines, position: playback.position,
            snapshotDate: playback.snapshotDate, duration: 400,
            isPlaying: playback.isPlaying, isVisible: true, isStale: false,
            offset: 0, onSeek: { playback.update(position: $0, isPlaying: playback.isPlaying) })
            .id(playback.source)
            .padding(14)
            .frame(width: 380, height: 360)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}
