import Foundation

/// Режим повтора. Spotify поддерживает только off/all (boolean repeating в
/// AppleScript); one зарезервирован под источники с полноценным repeat-one.
enum RepeatMode: String, Sendable, Equatable {
    case off
    case all
    case one

    /// Следующий режим по кругу для кнопки-переключателя.
    func next(supportsOne: Bool) -> RepeatMode {
        switch self {
        case .off: .all
        case .all: supportsOne ? .one : .off
        case .one: .off
        }
    }
}

/// Вторичное playback-состояние из снапшота; nil-поля — источник его не отдал.
struct PlaybackSecondaryState: Equatable, Sendable {
    var isShuffling: Bool?
    var repeatMode: RepeatMode?
    var volume: Int?
}

/// Что умеет активный источник. UI скрывает контролы без capability —
/// §11 P2 анализа. Матрица зафиксирована живым спайком 2026-07-24:
/// у Music set shuffle/repeat молча игнорируются без активной очереди.
struct PlaybackCapabilities: OptionSet, Sendable {
    let rawValue: Int

    static let seek = PlaybackCapabilities(rawValue: 1 << 0)
    static let volume = PlaybackCapabilities(rawValue: 1 << 1)
    static let shuffle = PlaybackCapabilities(rawValue: 1 << 2)
    static let repeatTrack = PlaybackCapabilities(rawValue: 1 << 3)

    static func capabilities(for source: PlaybackSource) -> PlaybackCapabilities {
        switch source {
        case .spotify:
            [.seek, .volume, .shuffle, .repeatTrack]
        case .appleMusic:
            [.seek, .volume]
        }
    }
}
