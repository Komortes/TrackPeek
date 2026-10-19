import SwiftUI

/// Второстепенные контролы (shuffle / repeat / громкость). Показывает только
/// то, что умеет активный источник (capability-модель): для Music кнопок
/// shuffle/repeat нет вовсе, а не disabled — §11 P2 анализа.
struct SecondaryControlsView: View {
    let capabilities: PlaybackCapabilities
    let secondary: PlaybackSecondaryState?
    let snapshotDate: Date
    let onShuffle: (Bool) -> Void
    let onRepeat: (RepeatMode) -> Void
    let onVolume: (Int) -> Void

    /// Локальное значение на время перетаскивания, чтобы слайдер не дёргался
    /// от асинхронного округления источника (Spotify: 55 → 54).
    @State private var volumeState = VolumeControlState()

    var body: some View {
        HStack(spacing: 10) {
            if capabilities.contains(.shuffle) {
                toggleButton(
                    symbol: "shuffle",
                    label: String(localized: "Shuffle"),
                    isOn: secondary?.isShuffling == true
                ) {
                    onShuffle(!(secondary?.isShuffling == true))
                }
            }

            if capabilities.contains(.repeatTrack) {
                toggleButton(
                    symbol: repeatSymbol,
                    label: String(localized: "Repeat"),
                    isOn: (secondary?.repeatMode ?? .off) != .off
                ) {
                    // Spotify не умеет repeat-one — цикл off → all → off.
                    onRepeat((secondary?.repeatMode ?? .off).next(supportsOne: false))
                }
            }

            if capabilities.contains(.volume) {
                HStack(spacing: 6) {
                    Image(systemName: volumeState.displayedValue(snapshot: secondary?.volume) == 0
                        ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    Slider(
                        value: Binding(
                            get: { volumeState.displayedValue(snapshot: secondary?.volume) },
                            set: { value in
                                if let volume = volumeState.change(to: value) { onVolume(volume) }
                            }
                        ),
                        in: 0 ... 100,
                        step: 1
                    ) { editing in
                        if let volume = volumeState.editingChanged(editing) { onVolume(volume) }
                    }
                    .controlSize(.mini)
                    .focusable(interactions: .edit)
                    .onKeyPress(keys: [.leftArrow, .rightArrow], phases: .down) { press in
                        guard PlaybackKeyboardInput.accepts(press.modifiers) else { return .ignored }
                        let step = press.key == .rightArrow ? 1.0 : -1.0
                        if let volume = volumeState.change(to: volumeState.displayedValue(snapshot: secondary?.volume) + step) {
                            onVolume(volume)
                        }
                        return .handled
                    }
                    .frame(maxWidth: 110)
                    .accessibilityLabel(String(localized: "Volume"))
                    .accessibilityValue(String(localized: "\(Int(volumeState.displayedValue(snapshot: secondary?.volume).rounded())) percent"))
                    .accessibilityHint(String(localized: "Left and right arrows change volume by one percent"))
                    .help(String(localized: "Player volume. ←/→ arrows: decrease/increase by one percent."))
                }
            }
        }
        .onChange(of: snapshotDate) { _, _ in volumeState.snapshotDidChange() }
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
