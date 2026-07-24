import SwiftUI

/// Разрешённые настройки активной поверхности (чёлка либо виджет), собранные
/// в один объект. Раньше содержимое (`compactContent`/`expandedContent`/
/// карточки виджета) само решало, чьи `@AppStorage`-значения брать через
/// `isPillMode ? widget… : notch…` — двенадцать раз подряд. Теперь эта
/// развилка происходит один раз в `NotchPlayerView`, а содержимое поверхности
/// просто читает уже разрешённые значения и не знает о существовании второй
/// поверхности.
struct OverlayAppearance {
    let width: Double
    let coloredProgress: Bool
    let coloredWaveform: Bool
    let colorSource: NotchColorSource
    let pulseMode: NotchPulseMode
    let outlineShimmer: Bool
    let outlineWidth: Double
    let equalizerSensitivityOverride: Double?
    let lyricsEnabled: Binding<Bool>
}
