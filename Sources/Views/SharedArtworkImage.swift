import SwiftUI

/// All artwork surfaces use the same loader, including low-resolution blur backgrounds.
struct SharedArtworkImage<Content: View>: View {
    let url: URL?
    let pointSize: CGFloat
    var maximumPixelSize: CGFloat = 1024
    @ViewBuilder let content: (AsyncImagePhase) -> Content

    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var presentation = ArtworkImagePresentation()

    private var key: ArtworkImageLoader.Key? {
        url.map { ArtworkImageLoader.Key(url: $0, pixelSize: min(pointSize * displayScale, maximumPixelSize)) }
    }

    private var phase: AsyncImagePhase {
        if let image = presentation.image(for: key) {
            return .success(Image(decorative: image, scale: displayScale))
        }
        return presentation.failed(for: key) ? .failure(URLError(.cannotDecodeContentData)) : .empty
    }

    var body: some View {
        content(phase)
            .task(id: key) {
                guard !Task.isCancelled else { return }
                let requestKey = key
                let request = presentation.begin(requestKey)
                guard let requestKey else { return }
                let result = await ArtworkImageLoader.shared.image(
                    for: requestKey.url, pixelSize: CGFloat(requestKey.pixels)
                )
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    presentation.complete(request, image: result)
                }
            }
    }
}

/// Holds at most one image. A size change can reuse the same URL's pixels,
/// but a different URL must never display the previous track's cover.
struct ArtworkImagePresentation {
    private var requestedKey: ArtworkImageLoader.Key?
    private var imageKey: ArtworkImageLoader.Key?
    private var loadedImage: CGImage?
    private var generation = 0
    private var finished = false

    mutating func begin(_ key: ArtworkImageLoader.Key?) -> Int {
        generation &+= 1
        requestedKey = key
        finished = false
        if key == nil || key?.url != imageKey?.url {
            loadedImage = nil
            imageKey = nil
        }
        return generation
    }

    mutating func complete(_ request: Int, image: CGImage?) {
        guard request == generation, let requestedKey else { return }
        finished = true
        if let image {
            loadedImage = image
            imageKey = requestedKey
        }
    }

    func image(for key: ArtworkImageLoader.Key?) -> CGImage? {
        guard let key, key.url == imageKey?.url else { return nil }
        return loadedImage
    }

    func failed(for key: ArtworkImageLoader.Key?) -> Bool {
        key != nil && key == requestedKey && finished && image(for: key) == nil
    }
}
