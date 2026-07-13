import SwiftUI

struct PlayerLayoutPreview: View {
    let layout: PlayerLayout

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary.opacity(0.7))

            preview
                .padding(12)
        }
        .frame(height: 104)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var preview: some View {
        switch layout {
        case .compactHorizontal:
            HStack(spacing: 9) {
                artwork(size: 52)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        textLines
                        Spacer(minLength: 4)
                        controls
                    }
                    progress
                }
            }

        case .standard:
            VStack(spacing: 6) {
                HStack(spacing: 9) {
                    artwork(size: 48)
                    textLines
                }
                VStack(spacing: 4) {
                    progress
                    controls
                }
                .padding(5)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 7))
            }

        case .artworkVertical:
            VStack(spacing: 4) {
                artwork(size: 43)
                controls
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.thinMaterial, in: Capsule())
                textLines
                progress
            }
            .frame(maxWidth: 90)
        }
    }

    private func artwork(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Color.accentColor.opacity(0.45))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
    }

    private var textLines: some View {
        VStack(alignment: .leading, spacing: 4) {
            Capsule()
                .fill(.primary.opacity(0.48))
                .frame(width: 66, height: 5)
            Capsule()
                .fill(.secondary.opacity(0.34))
                .frame(width: 48, height: 4)
        }
    }

    private var progress: some View {
        Capsule()
            .fill(.secondary.opacity(0.18))
            .frame(height: 3)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Color.accentColor.opacity(0.7))
                    .frame(width: 48, height: 3)
            }
    }

    private var controls: some View {
        HStack(spacing: 7) {
            Image(systemName: "backward.fill")
            Image(systemName: "pause.fill")
            Image(systemName: "forward.fill")
        }
        .font(.system(size: 7, weight: .semibold))
        .foregroundStyle(.secondary)
    }
}
