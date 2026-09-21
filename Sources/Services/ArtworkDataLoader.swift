import Foundation

/// Shared encoded artwork: a bounded memory cache and at most four downloads.
/// A consumer leaving must not cancel a download another surface still needs.
actor ArtworkDataLoader {
    static let shared = ArtworkDataLoader()
    static let maximumDataBytes = 8_000_000
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        // The bounded cache below owns reuse; do not retain a second HTTP cache
        // or persist a corrupt successful response across retries.
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: configuration)
    }()

    private struct Request {
        let id = UUID()
        var waiters: [UUID: CheckedContinuation<Data, Error>] = [:]
        var task: Task<Void, Never>?
    }

    private let maximumCacheBytes: Int
    private let loadData: @Sendable (URL) async throws -> Data
    private var cache: [URL: Data] = [:]
    private var cacheOrder: [URL] = []
    private(set) var cachedByteCount = 0
    private var requests: [URL: Request] = [:]
    private var queue: [URL] = []
    private var runningIDs: Set<UUID> = []

    init(
        maximumCacheBytes: Int = 8_000_000,
        loadData: @escaping @Sendable (URL) async throws -> Data = ArtworkDataLoader.readData
    ) {
        self.maximumCacheBytes = max(0, maximumCacheBytes)
        self.loadData = loadData
    }

    deinit {
        for request in requests.values {
            request.task?.cancel()
            for waiter in request.waiters.values { waiter.resume(throwing: CancellationError()) }
        }
    }

    func data(for url: URL) async throws -> Data {
        try Task.checkCancellation()
        guard ["https", "http", "file"].contains(url.scheme?.lowercased() ?? "") else {
            throw URLError(.unsupportedURL)
        }
        if let data = cache[url] {
            cacheOrder.removeAll { $0 == url }
            cacheOrder.append(url)
            return data
        }
        let waiterID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if requests[url] == nil {
                    requests[url] = Request()
                    queue.append(url)
                }
                requests[url]?.waiters[waiterID] = continuation
                startPendingRequests()
            }
        } onCancel: {
            Task { await self.cancel(waiterID, for: url) }
        }
    }

    func discard(_ data: Data, for url: URL) {
        guard cache[url] == data else { return }
        cachedByteCount -= cache.removeValue(forKey: url)?.count ?? 0
        cacheOrder.removeAll { $0 == url }
    }

    private func cancel(_ waiterID: UUID, for url: URL) {
        guard var request = requests[url], let waiter = request.waiters.removeValue(forKey: waiterID) else { return }
        waiter.resume(throwing: CancellationError())
        if request.waiters.isEmpty {
            request.task?.cancel()
            requests[url] = nil
            queue.removeAll { $0 == url }
            startPendingRequests()
        } else {
            requests[url] = request
        }
    }

    private func startPendingRequests() {
        while runningIDs.count < 4, !queue.isEmpty {
            let url = queue.removeFirst()
            guard let request = requests[url] else { continue }
            let id = request.id
            runningIDs.insert(id)
            let loadData = loadData
            requests[url]?.task = Task.detached(priority: .utility) { [weak self] in
                let result: Result<Data, Error>
                do {
                    try Task.checkCancellation()
                    let data = try await loadData(url)
                    try Task.checkCancellation()
                    guard data.count <= Self.maximumDataBytes else { throw URLError(.dataLengthExceedsMaximum) }
                    result = .success(data)
                } catch { result = .failure(error) }
                await self?.complete(result, for: url, id: id)
            }
        }
    }

    private func complete(_ result: Result<Data, Error>, for url: URL, id: UUID) {
        runningIDs.remove(id)
        defer { startPendingRequests() }
        guard let request = requests[url], request.id == id else { return }
        requests[url] = nil
        if case .success(let data) = result, data.count <= maximumCacheBytes {
            cache[url] = data
            cacheOrder.append(url)
            cachedByteCount += data.count
            while cachedByteCount > maximumCacheBytes || cacheOrder.count > 48 {
                let evicted = cacheOrder.removeFirst()
                cachedByteCount -= cache.removeValue(forKey: evicted)?.count ?? 0
            }
        }
        for waiter in request.waiters.values { waiter.resume(with: result) }
    }

    nonisolated static func readData(_ url: URL) async throws -> Data {
        if url.isFileURL {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: maximumDataBytes + 1) ?? Data()
            guard data.count <= maximumDataBytes else { throw URLError(.dataLengthExceedsMaximum) }
            return data
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (bytes, response) = try await session.bytes(for: request)
        defer { bytes.task.cancel() }
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        guard response.expectedContentLength <= maximumDataBytes else { throw URLError(.dataLengthExceedsMaximum) }
        var data = Data()
        for try await byte in bytes {
            guard data.count < maximumDataBytes else { throw URLError(.dataLengthExceedsMaximum) }
            data.append(byte)
        }
        return data
    }
}
