import SwiftUI

/// All artwork surfaces use the same loader, including low-resolution blur backgrounds.
struct SharedArtworkImage<Content: View>: View {
    let url: URL?
    let pointSize: CGFloat
    var maximumPixelSize: CGFloat = 1024
    @ViewBuilder let content: (AsyncImagePhase) -> Content

    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: CGImage?
    @State private var loadedKey: ArtworkImageLoader.Key?
    @State private var finished = false

    private var key: ArtworkImageLoader.Key? {
        url.map { ArtworkImageLoader.Key(url: $0, pixelSize: min(pointSize * displayScale, maximumPixelSize)) }
    }

    private var phase: AsyncImagePhase {
        guard let key, loadedKey == key else { return .empty }
        if let image { return .success(Image(decorative: image, scale: displayScale)) }
        return finished ? .failure(URLError(.cannotDecodeContentData)) : .empty
    }

    var body: some View {
        content(phase)
            .task(id: key) {
                guard !Task.isCancelled else { return }
                let requestKey = key
                loadedKey = requestKey
                image = nil
                finished = false
                guard let requestKey else { return }
                let result = await ArtworkImageLoader.shared.image(
                    for: requestKey.url, pixelSize: CGFloat(requestKey.pixels)
                )
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    image = result
                    finished = true
                }
            }
    }
}
