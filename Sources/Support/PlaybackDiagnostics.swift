import Foundation

/// Explicit allowlist: no track metadata, raw errors, file paths or history.
struct PlaybackDiagnostics {
    let source: PlaybackSource?
    let availability: PlaybackAvailability
    let isStale: Bool
    let isSleeping: Bool
    let lastSuccessfulRefresh: Date?
    let nextRefreshDate: Date?
    let audioStatus: AudioAnalysisStatus

    var connection: String {
        if isSleeping { return "Приостановлено до пробуждения" }
        if isStale { return "Нет связи · показан последний трек" }
        switch availability {
        case .loading: return "Проверка подключения"
        case .ready: return "Подключён"
        case .nothingPlaying: return "Подключён · нет трека"
        case .spotifyNotRunning: return "Плеер не запущен"
        case .automationDenied: return "Нет разрешения Automation"
        case .unavailable: return "Плеер временно недоступен"
        }
    }

    var permission: String {
        switch availability {
        case .ready, .nothingPlaying: "Доступ подтверждён"
        case .automationDenied: "Доступ запрещён"
        case .spotifyNotRunning: "Для проверки запустите плеер"
        case .loading, .unavailable: "Доступ не подтверждён"
        }
    }

    var retryStatus: String {
        if isSleeping { return "После пробуждения" }
        if availability == .automationDenied { return "После разрешения доступа нажмите «Проверить снова»" }
        return nextRefreshDate == nil ? "Проверка сейчас или по запросу" : "Автоматически"
    }

    func report(version: String, build: String) -> String {
        let formatter = ISO8601DateFormatter()
        return [
            "TrackPeek \(version) (\(build))",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Источник: \(source?.displayName ?? "Не определён")",
            "Соединение: \(connection)",
            "Automation: \(permission)",
            "Последняя успешная проверка: \(lastSuccessfulRefresh.map(formatter.string(from:)) ?? "Ещё не было")",
            "Следующая проверка: \(nextRefreshDate.map(formatter.string(from:)) ?? retryStatus)",
            "Аудиоанализ: \(audioStatus.description)",
        ].joined(separator: "\n")
    }
}
