import AppKit

enum AppleScriptExecutionError: LocalizedError {
    case scriptFailed(String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case let .scriptFailed(message):
            message
        case .timedOut:
            "Приложение не отвечает"
        }
    }
}

enum AppleScriptExecutor {
    /// Runs the blocking `NSAppleScript` call off the caller's executor so a
    /// hung/unresponsive app can't stall every other queued command; a
    /// sibling task races it with a timeout and wins if the app never replies.
    static func execute(
        _ source: String,
        timeout: Duration = .seconds(5)
    ) async throws -> NSAppleEventDescriptor {
        let scriptTask = Task.detached(priority: .userInitiated) { () -> UncheckedSendableBox<NSAppleEventDescriptor> in
            guard let script = NSAppleScript(source: source) else {
                throw AppleScriptExecutionError.scriptFailed("не удалось создать AppleScript")
            }

            var errorInfo: NSDictionary?
            let result = script.executeAndReturnError(&errorInfo)

            if let errorInfo {
                let message = errorInfo["NSAppleScriptErrorMessage"] as? String
                    ?? "неизвестная ошибка AppleScript"
                throw AppleScriptExecutionError.scriptFailed(message)
            }

            return UncheckedSendableBox(value: result)
        }

        return try await withThrowingTaskGroup(of: UncheckedSendableBox<NSAppleEventDescriptor>.self) { group in
            group.addTask { try await scriptTask.value }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw AppleScriptExecutionError.timedOut
            }

            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw AppleScriptExecutionError.timedOut
            }
            return result.value
        }
    }
}

/// Lets a non-Sendable AppleScript result cross a Task boundary; safe because
/// the value is produced once and consumed once, never shared concurrently.
private struct UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value
}
