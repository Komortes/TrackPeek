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
        if isSleeping { return String(localized: "Paused until wake") }
        if isStale { return String(localized: "Disconnected · showing the last track") }
        switch availability {
        case .loading: return String(localized: "Checking connection")
        case .ready: return String(localized: "Connected")
        case .nothingPlaying: return String(localized: "Connected · no track")
        case .spotifyNotRunning: return String(localized: "The player is not running")
        case .automationDenied: return String(localized: "Automation permission is missing")
        case .unavailable: return String(localized: "The player is temporarily unavailable")
        }
    }

    var permission: String {
        switch availability {
        case .ready, .nothingPlaying: String(localized: "Access confirmed")
        case .automationDenied: String(localized: "Access denied")
        case .spotifyNotRunning: String(localized: "Open the player to check access")
        case .loading, .unavailable: String(localized: "Access not confirmed")
        }
    }

    var retryStatus: String {
        if isSleeping { return String(localized: "After wake") }
        if availability == .automationDenied { return String(localized: "After granting access, click Check Again") }
        return nextRefreshDate == nil ? String(localized: "Checking now or on request") : String(localized: "Automatic")
    }

    func report(version: String, build: String) -> String {
        let formatter = ISO8601DateFormatter()
        return [
            "TrackPeek \(version) (\(build))",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            String(localized: "Source: \(source?.displayName ?? String(localized: "Unknown"))"),
            String(localized: "Connection: \(connection)"),
            String(localized: "Automation: \(permission)"),
            String(localized: "Last successful check: \(lastSuccessfulRefresh.map(formatter.string(from:)) ?? String(localized: "Not yet"))"),
            String(localized: "Next check: \(nextRefreshDate.map(formatter.string(from:)) ?? retryStatus)"),
            String(localized: "Audio analysis: \(audioStatus.description)"),
        ].joined(separator: "\n")
    }
}
