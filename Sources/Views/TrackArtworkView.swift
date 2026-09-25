import AppKit
import SwiftUI

struct TrackArtworkView: View {
    let url: URL?
    let size: CGFloat
    let cornerRadius: CGFloat
    let showsShadow: Bool

    init(
        url: URL?,
        size: CGFloat = 100,
        cornerRadius: CGFloat = 12,
        showsShadow: Bool = true
    ) {
        self.url = url
        self.size = size
        self.cornerRadius = cornerRadius
        self.showsShadow = showsShadow
    }

    var body: some View {
        SharedArtworkImage(url: url, pointSize: size) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            case .empty:
                ArtworkPlaceholderView(size: size, isLoading: url != nil)
                    .id(url)
            case .failure:
                ArtworkPlaceholderView(size: size, isLoading: false)
            @unknown default:
                ArtworkPlaceholderView(size: size, isLoading: false)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        }
        .shadow(
            color: showsShadow ? .black.opacity(0.18) : .clear,
            radius: showsShadow ? 8 : 0,
            y: showsShadow ? 3 : 0
        )
        .accessibilityHidden(true)
    }

}

/// A brief cache hit should not flash a spinner. Small and quiet surfaces use
/// a static symbol; the single delay task is cancelled when loading ends.
private struct ArtworkPlaceholderView: View {
    let size: CGFloat
    let isLoading: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.resourceSaving) private var resourceSaving
    @State private var showsProgress = false

    private var canAnimate: Bool { isLoading && size >= 32 && !reduceMotion && !resourceSaving }

    var body: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)
            Image(systemName: "music.note")
                .font(.system(size: min(max(size * 0.28, 8), 30), weight: .semibold))
                .foregroundStyle(.secondary)
                .opacity(showsProgress && canAnimate ? 0 : 1)
            if showsProgress && canAnimate {
                ProgressView()
                    .controlSize(.small)
                    .tint(.secondary)
            }
        }
        .task(id: canAnimate) {
            showsProgress = false
            guard canAnimate else { return }
            do { try await Task.sleep(for: .milliseconds(200)) }
            catch { return }
            guard !Task.isCancelled else { return }
            showsProgress = true
        }
    }
}
