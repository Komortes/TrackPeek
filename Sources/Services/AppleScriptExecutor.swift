import AppKit
import Darwin

enum AppleScriptExecutionError: LocalizedError {
    case scriptFailed(String)
    case timedOut
    case busy
    case automationDenied
    case helperUnavailable

    var errorDescription: String? {
        switch self {
        case let .scriptFailed(message): message
        case .timedOut: "Приложение не отвечает"
        case .busy: "Предыдущая команда плеера ещё выполняется"
        case .automationDenied: "Нет разрешения Automation"
        case .helperUnavailable: "Подключение к плееру прервано. Выполняется восстановление"
        }
    }
}

/// The app never executes NSAppleScript. One reusable child owns its main-thread
/// script engine; deadlines can terminate that child without stranding this app.
final class AppleScriptExecutor: Sendable {
    private static let shared = AppleScriptExecutor()
    private let supervisor = ScriptSupervisor()

    static func execute(
        _ source: String,
        timeout: Duration = .seconds(5),
        targetBundleIdentifier: String? = nil
    ) async throws -> NSAppleEventDescriptor {
        try await shared.run(source, timeout: timeout, targetBundleIdentifier: targetBundleIdentifier)
    }

    func run(
        _ source: String,
        timeout: Duration = .seconds(5),
        targetBundleIdentifier: String? = nil
    ) async throws -> NSAppleEventDescriptor {
        try Task.checkCancellation()
        return try await supervisor.execute(
            source, timeout: timeout, targetBundleIdentifier: targetBundleIdentifier
        ).value
    }

    func shutdown() async { await supervisor.shutdown() }
    var processIdentifier: Int32? { get async { await supervisor.processIdentifier } }
    var pendingRequestCount: Int { get async { await supervisor.pendingRequestCount } }
}

private struct ScriptResult: @unchecked Sendable {
    // Descriptor is fully constructed before crossing the actor boundary and
    // is owned by just the receiving caller afterwards.
    let value: NSAppleEventDescriptor
}

private final class ScriptCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    var isCancelled: Bool { lock.withLock { cancelled } }
    func cancel() { lock.withLock { cancelled = true } }
}

private actor ScriptSupervisor {
    private final class Request {
        let wire: AppleScriptRequest
        let cancellation: ScriptCancellation
        let continuation: CheckedContinuation<ScriptResult, Error>
        var deadlineTask: Task<Void, Never>?
        var deadline: ContinuousClock.Instant = .now
        var deadlineRevision = 0
        var isAwaitingConsent = false

        init(wire: AppleScriptRequest, cancellation: ScriptCancellation,
             continuation: CheckedContinuation<ScriptResult, Error>) {
            self.wire = wire
            self.cancellation = cancellation
            self.continuation = continuation
        }

        func finish(_ result: Result<ScriptResult, Error>) {
            deadlineTask?.cancel()
            continuation.resume(with: result)
        }
    }

    private var active: Request?
    private var pending: [Request] = []
    private var worker: ScriptWorker?
    private var generation = UUID()
    private let helperURL = Bundle.main.bundleURL
        .appendingPathComponent("Contents/Helpers/TrackPeekScriptHelper")

    var processIdentifier: Int32? { worker?.processIdentifier }
    var pendingRequestCount: Int { pending.count + (active == nil ? 0 : 1) }

    func execute(_ source: String, timeout: Duration, targetBundleIdentifier: String?) async throws -> ScriptResult {
        try Task.checkCancellation()
        guard timeout > .zero else { throw AppleScriptExecutionError.timedOut }
        guard source.utf8.count <= AppleScriptIPC.maximumSourceLength else {
            throw AppleScriptExecutionError.scriptFailed("Слишком большой запрос к плееру")
        }
        let id = UUID()
        let cancellation = ScriptCancellation()
        let deadline = ContinuousClock.now.advanced(by: timeout)
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                guard pendingRequestCount < 16 else {
                    continuation.resume(throwing: AppleScriptExecutionError.busy)
                    return
                }
                let request = Request(
                    wire: AppleScriptRequest(id: id, source: source, targetBundleIdentifier: targetBundleIdentifier),
                    cancellation: cancellation, continuation: continuation
                )
                setDeadline(request, at: deadline)
                pending.append(request)
                startNext()
            }
        } onCancel: {
            // A queued request can be selected before the actor processes the
            // cancellation message. The flag prevents sending it in that gap.
            cancellation.cancel()
            Task { await self.cancel(id) }
        }
    }

    private func setDeadline(_ request: Request, at deadline: ContinuousClock.Instant) {
        request.deadlineTask?.cancel()
        request.deadline = deadline
        request.deadlineRevision += 1
        let revision = request.deadlineRevision
        let id = request.wire.id
        request.deadlineTask = Task { [weak self] in
            do {
                try await Task.sleep(until: deadline, clock: .continuous)
                await self?.expire(id, revision: revision)
            } catch { }
        }
    }

    private func startNext() {
        guard active == nil else { return }
        while !pending.isEmpty {
            let request = pending.removeFirst()
            guard !request.cancellation.isCancelled else {
                request.finish(.failure(CancellationError()))
                continue
            }
            guard ContinuousClock.now < request.deadline else {
                request.finish(.failure(AppleScriptExecutionError.timedOut))
                continue
            }
            active = request
            do {
                if worker == nil {
                    generation = UUID()
                    let currentGeneration = generation
                    worker = try ScriptWorker(url: helperURL) { [weak self] in
                        Task { await self?.workerExited(generation: currentGeneration) }
                    }
                }
                guard let worker else { throw AppleScriptExecutionError.helperUnavailable }
                let currentGeneration = generation
                let wire = request.wire
                let cancellation = request.cancellation
                let deadline = request.deadline
                // Blocking pipe I/O never occupies the supervisor actor or the
                // UI thread, so even a stopped child can be killed on deadline.
                let supervisor = self
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try worker.send(wire, cancellation: cancellation, deadline: deadline)
                        while let reply = try worker.read() {
                            guard reply.version == 1, reply.id == wire.id else {
                                throw AppleScriptExecutionError.helperUnavailable
                            }
                            Task { await supervisor.receive(reply, generation: currentGeneration) }
                            if reply.kind == .result { return }
                        }
                        throw AppleScriptExecutionError.helperUnavailable
                    } catch {
                        Task { await supervisor.transportFailed(id: wire.id, generation: currentGeneration, error: error) }
                    }
                }
            } catch {
                failGeneration(activeError: AppleScriptExecutionError.helperUnavailable)
            }
            return
        }
    }

    private func receive(_ reply: AppleScriptResponse, generation: UUID) {
        guard self.generation == generation, let active, active.wire.id == reply.id else { return }
        if active.cancellation.isCancelled {
            failGeneration(activeError: CancellationError())
            return
        }
        if reply.kind == .permissionPending {
            guard !active.isAwaitingConsent, active.wire.targetBundleIdentifier != nil,
                  reply.descriptor == nil, reply.errorNumber == nil, reply.errorMessage == nil else {
                failGeneration(activeError: AppleScriptExecutionError.helperUnavailable)
                return
            }
            // An initial system consent dialog can legitimately outlive a
            // normal five-second poll. Extend once; never resend the command.
            active.isAwaitingConsent = true
            setDeadline(active, at: .now.advanced(by: .seconds(120)))
            return
        }

        let result: Result<ScriptResult, Error>
        if let data = reply.descriptor, reply.errorNumber == nil, reply.errorMessage == nil {
            do {
                guard let descriptor = try NSKeyedUnarchiver.unarchivedObject(
                    ofClass: NSAppleEventDescriptor.self, from: data
                ) else { throw AppleScriptExecutionError.helperUnavailable }
                result = .success(ScriptResult(value: descriptor))
            } catch {
                failGeneration(activeError: AppleScriptExecutionError.helperUnavailable)
                return
            }
        } else if reply.descriptor == nil, let code = reply.errorNumber {
            switch code {
            case -1712:
                failGeneration(activeError: AppleScriptExecutionError.timedOut)
                return
            case -1743, -1744:
                result = .failure(AppleScriptExecutionError.automationDenied)
            default:
                result = .failure(AppleScriptExecutionError.scriptFailed(reply.errorMessage ?? "Ошибка плеера"))
            }
        } else {
            failGeneration(activeError: AppleScriptExecutionError.helperUnavailable)
            return
        }
        self.active = nil
        active.finish(result)
        startNext()
    }

    private func cancel(_ id: UUID) {
        if active?.wire.id == id {
            failGeneration(activeError: CancellationError())
        } else if let index = pending.firstIndex(where: { $0.wire.id == id }) {
            pending.remove(at: index).finish(.failure(CancellationError()))
        }
    }

    private func expire(_ id: UUID, revision: Int) {
        if let active, active.wire.id == id, active.deadlineRevision == revision {
            failGeneration(activeError: active.cancellation.isCancelled
                ? CancellationError() : AppleScriptExecutionError.timedOut)
        } else if let index = pending.firstIndex(where: { $0.wire.id == id && $0.deadlineRevision == revision }) {
            let request = pending.remove(at: index)
            request.finish(.failure(request.cancellation.isCancelled
                ? CancellationError() : AppleScriptExecutionError.timedOut))
        }
    }

    private func transportFailed(id: UUID, generation: UUID, error: Error) {
        guard self.generation == generation, let active, active.wire.id == id else { return }
        if active.cancellation.isCancelled {
            failGeneration(activeError: CancellationError())
        } else if case AppleScriptExecutionError.timedOut = error {
            failGeneration(activeError: AppleScriptExecutionError.timedOut)
        } else {
            failGeneration(activeError: AppleScriptExecutionError.helperUnavailable)
        }
    }

    private func workerExited(generation: UUID) {
        guard self.generation == generation else { return }
        failGeneration(activeError: active?.cancellation.isCancelled == true
            ? CancellationError() : AppleScriptExecutionError.helperUnavailable)
    }

    func shutdown() { failGeneration(activeError: CancellationError()) }

    private func failGeneration(activeError: Error) {
        generation = UUID()
        worker?.stop()
        worker = nil
        let oldActive = active
        let oldPending = pending
        active = nil
        pending.removeAll(keepingCapacity: true)
        if let oldActive {
            oldActive.finish(.failure(oldActive.cancellation.isCancelled ? CancellationError() : activeError))
        }
        // Never replay a request after an ambiguous failure, including commands
        // that had accumulated while the old worker was unresponsive.
        for request in oldPending {
            request.finish(.failure(request.cancellation.isCancelled
                ? CancellationError() : AppleScriptExecutionError.helperUnavailable))
        }
    }
}

/// Only the I/O task touches the pipe handles. stop() kills the owned child,
/// which releases blocking reads/writes; handles close after that task returns.
private final class ScriptWorker: @unchecked Sendable {
    private let process: Process
    private let input: FileHandle
    private let output: FileHandle
    private let lock = NSLock()

    init(url: URL, onExit: @escaping @Sendable () -> Void) throws {
        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        process.executableURL = url
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { _ in onExit() }
        self.process = process
        input = stdin.fileHandleForWriting
        output = stdout.fileHandleForReading
        do {
            try process.run()
        } catch {
            process.terminationHandler = nil
            throw error
        }
        try? stdin.fileHandleForReading.close()
        try? stdout.fileHandleForWriting.close()
    }

    var processIdentifier: Int32? {
        lock.withLock { process.isRunning ? process.processIdentifier : nil }
    }

    func send(_ request: AppleScriptRequest, cancellation: ScriptCancellation,
              deadline: ContinuousClock.Instant) throws {
        guard !cancellation.isCancelled else { throw CancellationError() }
        guard ContinuousClock.now < deadline else { throw AppleScriptExecutionError.timedOut }
        try AppleScriptIPC.write(request, to: input.fileDescriptor)
    }

    func read() throws -> AppleScriptResponse? {
        try AppleScriptIPC.read(AppleScriptResponse.self, from: output.fileDescriptor)
    }

    func stop() {
        lock.withLock {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
    }

    deinit {
        stop()
        try? input.close()
        try? output.close()
    }
}
