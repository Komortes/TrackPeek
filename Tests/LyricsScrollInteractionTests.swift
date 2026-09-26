import AppKit
import Testing
@testable import TrackPeek

@MainActor
@Suite("Lyrics scroll interaction")
struct LyricsScrollInteractionTests {
    @Test("live scroll notifications from the enclosing scroll view report user intent")
    func ownLiveScrollIsObserved() async {
        let host = ScrollObserverHost()
        defer { host.close() }
        let observer = LyricsScrollObserverView()
        var events = 0
        observer.onUserScroll = { events += 1 }
        host.document.addSubview(observer)
        await drainMainQueue()

        NotificationCenter.default.post(name: NSScrollView.willStartLiveScrollNotification, object: host.scrollView)
        NotificationCenter.default.post(name: NSScrollView.didLiveScrollNotification, object: host.scrollView)
        #expect(events == 2)
        #expect(!host.window.isVisible)
        #expect(observer.hitTest(.zero) == nil)
    }

    @Test("another scroll view cannot interrupt lyric following")
    func unrelatedScrollIsIgnored() async {
        let host = ScrollObserverHost()
        let otherHost = ScrollObserverHost()
        defer { host.close(); otherHost.close() }
        let observer = LyricsScrollObserverView()
        var events = 0
        observer.onUserScroll = { events += 1 }
        host.document.addSubview(observer)
        await drainMainQueue()

        NotificationCenter.default.post(name: NSScrollView.willStartLiveScrollNotification, object: otherHost.scrollView)
        NotificationCenter.default.post(name: NSScrollView.didLiveScrollNotification, object: otherHost.scrollView)
        #expect(events == 0)
        NotificationCenter.default.post(name: NSScrollView.didLiveScrollNotification, object: host.scrollView)
        #expect(events == 1)
    }

    @Test("programmatic content movement does not report user scrolling")
    func programmaticScrollIsIgnored() async {
        let host = ScrollObserverHost()
        defer { host.close() }
        let observer = LyricsScrollObserverView()
        var events = 0
        observer.onUserScroll = { events += 1 }
        host.document.addSubview(observer)
        await drainMainQueue()

        host.scrollView.contentView.postsBoundsChangedNotifications = true
        host.scrollView.contentView.scroll(to: NSPoint(x: 0, y: 150))
        host.scrollView.reflectScrolledClipView(host.scrollView.contentView)
        await drainMainQueue()
        #expect(host.scrollView.contentView.bounds.origin.y == 150)
        #expect(events == 0)
    }

    @Test("reparenting observes only the new enclosing scroll view")
    func reparentingUpdatesObservedScrollView() async {
        let firstHost = ScrollObserverHost()
        let secondHost = ScrollObserverHost()
        defer { firstHost.close(); secondHost.close() }
        let observer = LyricsScrollObserverView()
        var events = 0
        observer.onUserScroll = { events += 1 }
        firstHost.document.addSubview(observer)
        await drainMainQueue()
        NotificationCenter.default.post(name: NSScrollView.didLiveScrollNotification, object: firstHost.scrollView)
        #expect(events == 1)

        observer.removeFromSuperview()
        NotificationCenter.default.post(name: NSScrollView.didLiveScrollNotification, object: firstHost.scrollView)
        #expect(events == 1)
        secondHost.document.addSubview(observer)
        await drainMainQueue()
        NotificationCenter.default.post(name: NSScrollView.didLiveScrollNotification, object: firstHost.scrollView)
        #expect(events == 1)
        NotificationCenter.default.post(name: NSScrollView.didLiveScrollNotification, object: secondHost.scrollView)
        #expect(events == 2)
    }

    @Test("detaching invalidates a queued attachment until explicitly requested again")
    func detachCancelsQueuedAttachment() async {
        let host = ScrollObserverHost()
        defer { host.close() }
        let observer = LyricsScrollObserverView()
        var events = 0
        observer.onUserScroll = { events += 1 }
        host.document.addSubview(observer)
        await drainMainQueue()

        observer.scheduleAttachment()
        observer.detach()
        await drainMainQueue()
        NotificationCenter.default.post(name: NSScrollView.didLiveScrollNotification, object: host.scrollView)
        #expect(events == 0)

        observer.scheduleAttachment()
        await drainMainQueue()
        NotificationCenter.default.post(name: NSScrollView.didLiveScrollNotification, object: host.scrollView)
        #expect(events == 1)
    }

    @Test("dismantling clears the callback even when attachment was already queued")
    func dismantlingClearsCallback() async {
        let host = ScrollObserverHost()
        defer { host.close() }
        let observer = LyricsScrollObserverView()
        var events = 0
        observer.onUserScroll = { events += 1 }
        host.document.addSubview(observer)
        LyricsScrollInteraction.dismantleNSView(observer, coordinator: ())
        await drainMainQueue()
        NotificationCenter.default.post(name: NSScrollView.didLiveScrollNotification, object: host.scrollView)
        #expect(events == 0)
        #expect(observer.onUserScroll == nil)
    }

    @Test("notification registration and queued attachment do not retain a removed observer")
    func removedObserverIsReleased() async {
        weak var releasedObserver: LyricsScrollObserverView?
        weak var releasedCallbackOwner: ScrollCallbackOwner?
        autoreleasepool {
            let host = ScrollObserverHost()
            let owner = ScrollCallbackOwner()
            var observer: LyricsScrollObserverView? = LyricsScrollObserverView()
            releasedObserver = observer
            releasedCallbackOwner = owner
            observer?.onUserScroll = { owner.events += 1 }
            host.document.addSubview(observer!)
            observer?.attach()
            observer?.scheduleAttachment()
            observer?.removeFromSuperview()
            observer = nil
            host.close()
        }
        await drainMainQueue()
        #expect(releasedObserver == nil)
        #expect(releasedCallbackOwner == nil)
    }
}

@MainActor
private final class ScrollObserverHost {
    let window: NSWindow
    let scrollView: NSScrollView
    let document: NSView

    init() {
        let frame = NSRect(x: 0, y: 0, width: 320, height: 200)
        window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        scrollView = NSScrollView(frame: frame)
        document = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 800))
        scrollView.documentView = document
        window.contentView = scrollView
    }

    func close() {
        window.contentView = nil
        scrollView.documentView = nil
        window.close()
    }
}

@MainActor
private final class ScrollCallbackOwner {
    var events = 0
}

/// Runs after attachments already enqueued on the main queue, without sleeps
/// or relying on how many times Swift's task scheduler happens to yield.
@MainActor
private func drainMainQueue() async {
    await withCheckedContinuation { continuation in
        DispatchQueue.main.async { continuation.resume() }
    }
}
