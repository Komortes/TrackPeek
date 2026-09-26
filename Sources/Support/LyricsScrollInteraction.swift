import AppKit
import SwiftUI

/// SwiftUI's scroll-phase callback requires newer macOS. These AppKit
/// notifications distinguish user input from ScrollViewReader.scrollTo on 14+.
struct LyricsScrollInteraction: NSViewRepresentable {
    let onUserScroll: () -> Void

    func makeNSView(context: Context) -> LyricsScrollObserverView {
        let view = LyricsScrollObserverView()
        view.onUserScroll = onUserScroll
        return view
    }

    func updateNSView(_ view: LyricsScrollObserverView, context: Context) {
        view.onUserScroll = onUserScroll
        view.scheduleAttachment()
    }

    static func dismantleNSView(_ view: LyricsScrollObserverView, coordinator: ()) {
        view.detach()
        view.onUserScroll = nil
    }
}

@MainActor
final class LyricsScrollObserverView: NSView {
    var onUserScroll: (() -> Void)?
    private weak var observedScrollView: NSScrollView?
    private var attachmentScheduled = false
    private var attachmentGeneration = 0

    deinit { NotificationCenter.default.removeObserver(self) }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        scheduleAttachment()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { detach() }
        else { scheduleAttachment() }
    }

    func scheduleAttachment() {
        guard !attachmentScheduled else { return }
        attachmentScheduled = true
        let generation = attachmentGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.attachmentGeneration == generation else { return }
            self.attachmentScheduled = false
            self.attach()
        }
    }

    func attach() {
        let scrollView = window == nil ? nil : enclosingScrollView
        guard scrollView !== observedScrollView else { return }
        detach()
        guard let scrollView else { return }
        observedScrollView = scrollView
        let center = NotificationCenter.default
        // willStart covers trackpad/scroller tracking; didLive also covers
        // legacy mouse wheels, whose events need not have a begin/end pair.
        for name in [NSScrollView.willStartLiveScrollNotification, NSScrollView.didLiveScrollNotification] {
            center.addObserver(self, selector: #selector(userScrolled), name: name, object: scrollView)
        }
    }

    func detach() {
        // A queued hierarchy update must not reattach after teardown. A later
        // explicit attachment gets a new generation and remains valid.
        attachmentGeneration &+= 1
        attachmentScheduled = false
        NotificationCenter.default.removeObserver(self)
        observedScrollView = nil
    }

    @objc private func userScrolled(_ notification: Notification) {
        onUserScroll?()
    }
}
