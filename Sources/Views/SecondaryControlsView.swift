import SwiftUI

/// Второстепенные контролы (shuffle / repeat / громкость). Показывает только
/// то, что умеет активный источник (capability-модель): для Music кнопок
/// shuffle/repeat нет вовсе, а не disabled — §11 P2 анализа.
struct SecondaryControlsView: View {
    let capabilities: PlaybackCapabilities
    let secondary: PlaybackSecondaryState?
    let onShuffle: (Bool) -> Void
    let onRepeat: (RepeatMode) -> Void
    let onVolume: (Int) -> Void

    /// Локальное значение на время перетаскивания, чтобы слайдер не дёргался
    /// от асинхронного округления источника (Spotify: 55 → 54).
    @State private var draftVolume: Double?

    var body: some View {
        HStack(spacing: 10) {
            if capabilities.contains(.shuffle) {
                toggleButton(
                    symbol: "shuffle",
                    label: "Перемешивание",
                    isOn: secondary?.isShuffling == true
                ) {
                    onShuffle(!(secondary?.isShuffling == true))
                }
            }

            if capabilities.contains(.repeatTrack) {
                toggleButton(
                    symbol: repeatSymbol,
                    label: "Повтор",
                    isOn: (secondary?.repeatMode ?? .off) != .off
                ) {
                    // Spotify не умеет repeat-one — цикл off → all → off.
                    onRepeat((secondary?.repeatMode ?? .off).next(supportsOne: false))
                }
            }

            if capabilities.contains(.volume) {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Slider(
                        value: Binding(
                            get: { draftVolume ?? Double(secondary?.volume ?? 50) },
                            set: { draftVolume = $0 }
                        ),
                        in: 0 ... 100
                    ) { editing in
                        guard !editing, let value = draftVolume else { return }
                        onVolume(Int(value.rounded()))
                        draftVolume = nil
                    }
                    .controlSize(.mini)
                    .frame(maxWidth: 110)
                    .accessibilityLabel("Громкость")
                }
            }
        }
    }

    private var repeatSymbol: String {
        secondary?.repeatMode == .one ? "repeat.1" : "repeat"
    }

    private func toggleButton(
        symbol: String,
        label: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                .frame(width: 24, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}
