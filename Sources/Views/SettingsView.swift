import SwiftUI

struct SettingsView: View {
    @AppStorage("displayMode") private var selectedModeRawValue = DisplayMode.fallback.rawValue

    private var selectedMode: DisplayMode {
        DisplayMode(rawValue: selectedModeRawValue) ?? .fallback
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Режим отображения")
                    .font(.title2.weight(.semibold))

                Text("Выберите, где TrackPeek будет показывать текущий трек и элементы управления.")
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 14) {
                ForEach(DisplayMode.allCases) { mode in
                    modeCard(mode)
                }
            }

            Divider()

            Label(
                "Сейчас доступен режим Menu Bar. Notch и Floating Widget будут добавлены отдельными рабочими этапами.",
                systemImage: "info.circle"
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 720, height: 410, alignment: .topLeading)
    }

    private func modeCard(_ mode: DisplayMode) -> some View {
        Button {
            selectedModeRawValue = mode.rawValue
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                modePreview(mode)

                HStack(alignment: .firstTextBaseline) {
                    Label(mode.title, systemImage: mode.symbolName)
                        .font(.headline)

                    Spacer(minLength: 4)

                    if selectedMode == mode {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }

                Text(mode.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                Text(mode.isAvailable ? "Доступен" : "В разработке")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(mode.isAvailable ? Color.green : Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        selectedMode == mode ? Color.accentColor : Color.primary.opacity(0.08),
                        lineWidth: selectedMode == mode ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(!mode.isAvailable)
        .opacity(mode.isAvailable ? 1 : 0.68)
        .help(mode.isAvailable ? "Выбрать \(mode.title)" : "Этот режим пока в разработке")
    }

    @ViewBuilder
    private func modePreview(_ mode: DisplayMode) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary)

            switch mode {
            case .menuBar:
                VStack(spacing: 0) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)
                        Text("Radiohead — Reckoner")
                            .lineLimit(1)
                        Image(systemName: "waveform")
                    }
                    .font(.system(size: 7, weight: .medium))
                    .padding(.horizontal, 8)
                    .frame(height: 19)
                    .frame(maxWidth: .infinity)
                    .background(.bar)

                    Spacer()
                }

            case .notch:
                VStack(spacing: 7) {
                    Capsule()
                        .fill(Color.black.opacity(0.86))
                        .frame(width: 72, height: 17)

                    HStack(spacing: 7) {
                        Image(systemName: "music.note")
                        Text("Reckoner")
                            .lineLimit(1)
                    }
                    .font(.system(size: 8, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.regularMaterial, in: Capsule())
                }

            case .floatingWidget:
                VStack {
                    Spacer()

                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.accentColor.opacity(0.55))
                            .frame(width: 31, height: 31)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Reckoner")
                                .fontWeight(.semibold)
                            Text("Radiohead")
                                .foregroundStyle(.secondary)
                        }
                        .font(.system(size: 7))

                        Spacer()

                        Image(systemName: "pause.fill")
                    }
                    .padding(9)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    .padding(10)
                }
            }
        }
        .frame(height: 112)
        .accessibilityHidden(true)
    }
}
