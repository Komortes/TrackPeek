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
        AsyncImage(
            url: url,
            transaction: Transaction(animation: .easeInOut(duration: 0.2))
        ) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            case .empty:
                placeholder(showsProgress: url != nil)
            case .failure:
                placeholder(showsProgress: false)
            @unknown default:
                placeholder(showsProgress: false)
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

    private func placeholder(showsProgress: Bool) -> some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)

            if showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .tint(.secondary)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
