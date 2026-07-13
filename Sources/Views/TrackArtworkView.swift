import SwiftUI

struct TrackArtworkView: View {
    let url: URL?

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
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: 14, y: 7)
        .accessibilityHidden(true)
    }

    private func placeholder(showsProgress: Bool) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.92),
                    Color.accentColor.opacity(0.42),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
    }
}
