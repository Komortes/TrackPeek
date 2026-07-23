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
    /// Все скрипты идут через одну последовательную GCD-очередь:
    /// 1) `NSAppleScript` не потокобезопасен — параллельное исполнение
    ///    приводило к порче состояния и подвисаниям;
    /// 2) блокирующий вызов больше не занимает поток кооперативного пула
    ///    Swift Concurrency — шквал команд (быстрое пролистывание + опросы)
    ///    раньше исчерпывал пул и замораживал весь UI.
    /// Таймаут-гонка сохранена: зависший плеер не держит вызывающего.
    private static let scriptQueue = DispatchQueue(
        label: "com.trackpeek.applescript",
        qos: .userInitiated
    )

    static func execute(
        _ source: String,
        timeout: Duration = .seconds(5)
    ) async throws -> NSAppleEventDescriptor {
        try await withThrowingTaskGroup(of: UncheckedSendableBox<NSAppleEventDescriptor>.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    scriptQueue.async {
                        guard let script = NSAppleScript(source: source) else {
                            continuation.resume(
                                throwing: AppleScriptExecutionError.scriptFailed(
                                    "не удалось создать AppleScript"
                                )
                            )
                            return
                        }

                        var errorInfo: NSDictionary?
                        let result = script.executeAndReturnError(&errorInfo)

                        if let errorInfo {
                            let message = errorInfo["NSAppleScriptErrorMessage"] as? String
                                ?? "неизвестная ошибка AppleScript"
                            continuation.resume(
                                throwing: AppleScriptExecutionError.scriptFailed(message)
                            )
                        } else {
                            continuation.resume(returning: UncheckedSendableBox(value: result))
                        }
                    }
                }
            }
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
