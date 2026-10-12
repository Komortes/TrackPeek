import Foundation

enum PlaybackTimeFormatter {
    static func string(from time: TimeInterval) -> String {
        guard time.isFinite,
              let secondsValue = Int(exactly: time.rounded(.towardZero)) else {
            return "0:00"
        }

        let totalSeconds = max(secondsValue, 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
