import AppKit

enum AppleScriptExecutionError: LocalizedError {
    case scriptFailed(String)
    case timedOut
    case busy

    var errorDescription: String? {
        switch self {
        case let .scriptFailed(message): message
        case .timedOut: "Приложение не отвечает"
        case .busy: "Предыдущая команда плеера ещё выполняется"
        }
    }
}

enum AppleScriptExecutor {
    private static let scriptQueue = DispatchQueue(
        label: "com.trackpeek.applescript",
        qos: .userInitiated
    )
    // A timed-out native call cannot be interrupted safely. Keep one
    // running script plus a bounded queue, so an unresponsive player cannot
    // grow it indefinitely. Normal overlapping polls and controls can wait.
    private static let slot = DispatchSemaphore(value: 16)

    private static func acquireSlot() -> Bool {
        slot.wait(timeout: .now()) == .success
    }

    static func execute(
        _ source: String,
        timeout: Duration = .seconds(5)
    ) async throws -> NSAppleEventDescriptor {
        try Task.checkCancellation()
        guard acquireSlot() else {
            throw AppleScriptExecutionError.busy
        }
        let completion = ScriptCompletion()
        let deadline = Task {
            do {
                try await Task.sleep(for: timeout)
                completion.finish(.failure(AppleScriptExecutionError.timedOut))
            } catch { }
        }
        defer { deadline.cancel() }

        let result = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                completion.install(continuation)
                scriptQueue.async {
                    defer { slot.signal() }
                    guard !completion.isFinished else { return }
                    autoreleasepool {
                        // Also bound Apple Events themselves. Unlike the Swift
                        // deadline, this lets the native call release its slot.
                        let wrapped = "with timeout of 5 seconds\n\(source)\nend timeout"
                        guard let script = NSAppleScript(source: wrapped) else {
                            completion.finish(.failure(AppleScriptExecutionError.scriptFailed(
                                "не удалось создать AppleScript"
                            )))
                            return
                        }
                        var errorInfo: NSDictionary?
                        let result = script.executeAndReturnError(&errorInfo)
                        if let errorInfo {
                            if errorInfo["NSAppleScriptErrorNumber"] as? Int == -1712 {
                                completion.finish(.failure(AppleScriptExecutionError.timedOut))
                            } else {
                                let message = errorInfo["NSAppleScriptErrorMessage"] as? String
                                    ?? "неизвестная ошибка AppleScript"
                                completion.finish(.failure(AppleScriptExecutionError.scriptFailed(message)))
                            }
                        } else {
                            completion.finish(.success(ScriptResult(value: result)))
                        }
                    }
                }
            }
        } onCancel: {
            completion.finish(.failure(CancellationError()))
        }
        return result.value
    }
}

private struct ScriptResult: @unchecked Sendable {
    let value: NSAppleEventDescriptor
}

/// Serializes timeout, cancellation and native completion; exactly one resumes
/// the caller, including cancellation before the continuation is installed.
private final class ScriptCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<ScriptResult, Error>?
    private var result: Result<ScriptResult, Error>?

    var isFinished: Bool {
        lock.withLock { result != nil }
    }

    func install(_ continuation: CheckedContinuation<ScriptResult, Error>) {
        let result = lock.withLock { () -> Result<ScriptResult, Error>? in
            if let result = self.result { return result }
            self.continuation = continuation
            return nil as Result<ScriptResult, Error>?
        }
        if let result { continuation.resume(with: result) }
    }

    func finish(_ result: Result<ScriptResult, Error>) {
        let continuation = lock.withLock {
            guard self.result == nil else { return nil as CheckedContinuation<ScriptResult, Error>? }
            self.result = result
            let continuation = self.continuation
            self.continuation = nil
            return continuation
        }
        continuation?.resume(with: result)
    }
}
