import AppKit
import Testing
@testable import TrackPeek

@Suite("Notch motion")
struct NotchMotionTests {
    @Test("the old and new titles never draw over each other during a resize")
    func contentLeavesBeforeNextStateAppears() {
        let compact = NotchContentPresentation(state: .collapsed)
        let expanded = NotchContentPresentation(state: .expanded)
        for step in 0 ... 20 {
            let presentation = compact.interpolated(to: expanded, progress: Double(step) / 20)
            #expect(presentation.opacity(for: .collapsed) == 0 || presentation.opacity(for: .expanded) == 0)
        }
        #expect(compact.opacity(for: .collapsed) == 1)
        #expect(expanded.opacity(for: .expanded) == 1)
    }

    @Test("an immediate layout stops the native resize instead of letting it resume")
    @MainActor func immediateFrameStopsNativeAnimation() async {
        let initial = NSRect(x: -10000, y: -10000, width: 320, height: 36)
        let panel = NSPanel(contentRect: initial, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        defer { panel.orderOut(nil) }
        let target = NSRect(x: -10048, y: -10140, width: 416, height: 176)

        await withCheckedContinuation { (completion: CheckedContinuation<Void, Never>) in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().setFrame(target, display: true)
            } completionHandler: {
                completion.resume()
            }
            NotchWindowMotion.setFrameImmediately(initial, on: panel)
        }
        #expect(panel.frame == initial)
    }

    @Test("an equal-size state change still updates content when switching from a card to a pill")
    @MainActor func equalSizeStateChangeUpdatesContent() {
        let size = CGSize(width: 416, height: 176)
        let layout = NotchPanelLayoutState(size: size)
        _ = layout.beginTransition(to: .expanded, size: size, from: size, animated: true)
        #expect(layout.targetState == .expanded)
        #expect(layout.presentation(at: size) == NotchContentPresentation(state: .expanded))
        _ = layout.beginTransition(to: .collapsed, size: size, from: size, animated: true)
        #expect(layout.targetState == .collapsed)
        #expect(layout.presentation(at: size) == NotchContentPresentation(state: .collapsed))
    }

    @Test("retargeting keeps the currently visible content instead of restarting the fade")
    @MainActor func retargetPreservesPresentation() {
        let compact = CGSize(width: 320, height: 36)
        let expanded = CGSize(width: 416, height: 176)
        let halfway = CGSize(width: 368, height: 106)
        let layout = NotchPanelLayoutState(size: compact)
        _ = layout.beginTransition(to: .expanded, size: expanded, from: compact, animated: true)
        let visible = layout.presentation(at: halfway)
        #expect(visible.expanded > 0 && visible.expanded < 1)

        _ = layout.beginTransition(to: .collapsed, size: compact, from: halfway, animated: true)
        #expect(layout.presentation(at: halfway) == visible)
        #expect(layout.presentation(at: compact) == NotchContentPresentation(state: .collapsed))
    }

    @Test("obsolete completions cannot settle a newer transition")
    @MainActor func obsoleteCompletionIsIgnored() {
        let compact = CGSize(width: 320, height: 36)
        let expanded = CGSize(width: 416, height: 176)
        let layout = NotchPanelLayoutState(size: compact)
        let old = layout.beginTransition(to: .expanded, size: expanded, from: compact, animated: true)
        let current = layout.beginTransition(to: .collapsed, size: compact,
                                             from: CGSize(width: 368, height: 106), animated: true)
        #expect(!layout.finishTransition(old))
        #expect(layout.finishTransition(current))
        #expect(layout.presentation(at: compact) == NotchContentPresentation(state: .collapsed))
    }

    @Test("nonanimated changes settle immediately and invalidate active completion")
    @MainActor func immediateLayoutInvalidatesAnimation() {
        let compact = CGSize(width: 320, height: 36)
        let expanded = CGSize(width: 416, height: 176)
        let layout = NotchPanelLayoutState(size: compact)
        let old = layout.beginTransition(to: .expanded, size: expanded, from: compact, animated: true)
        _ = layout.beginTransition(to: .notification, size: CGSize(width: 368, height: 68),
                                   from: compact, animated: false)
        #expect(!layout.finishTransition(old))
        #expect(layout.presentation(at: compact) == NotchContentPresentation(state: .notification))
    }

    @Test("closing the host invalidates its outstanding animation")
    @MainActor func closingInvalidatesCompletion() {
        let compact = CGSize(width: 320, height: 36)
        let layout = NotchPanelLayoutState(size: compact)
        let old = layout.beginTransition(to: .expanded, size: CGSize(width: 416, height: 176),
                                         from: compact, animated: true)
        layout.cancelTransition()
        #expect(!layout.finishTransition(old))
    }

    @Test("notification can fade into controls without exposing compact content")
    @MainActor func notificationToExpanded() {
        let notification = CGSize(width: 368, height: 68)
        let expanded = CGSize(width: 416, height: 176)
        let layout = NotchPanelLayoutState(size: notification)
        _ = layout.beginTransition(to: .notification, size: notification, from: notification, animated: false)
        _ = layout.beginTransition(to: .expanded, size: expanded, from: notification, animated: true)
        let visible = layout.presentation(at: CGSize(width: 392, height: 122))
        #expect(visible.compact == 0)
        #expect(abs(visible.notification + visible.expanded - 1) < 0.0001)
        #expect(visible.notification > 0 && visible.expanded > 0)
    }
}
