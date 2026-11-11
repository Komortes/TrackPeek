import AppKit
import Testing
@testable import TrackPeek

@Suite("Music artwork cache", .timeLimit(.minutes(1)))
struct MusicArtworkTests {
    @Test("a transient failure retries after a cooldown and reuses the recovered file")
    func transientRecovery() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = MusicArtworkResponses([.failure(URLError(.timedOut)), .success(Data([2]))])
        let clock = MusicArtworkClock()
        let client = MusicAppleScriptClient(artworkLoader: { try await source.load() },
                                            artworkDirectory: directory, artworkTime: { clock.now })
        #expect(try await client.resolvedArtworkURL(trackIdentity: "A") == nil)
        for _ in 0..<3 { #expect(try await client.resolvedArtworkURL(trackIdentity: "A") == nil) }
        #expect(await source.calls == 1)
        clock.advance(5)
        let recovered = try #require(try await client.resolvedArtworkURL(trackIdentity: "A"))
        #expect(try Data(contentsOf: recovered) == Data([2]))
        #expect(try await client.resolvedArtworkURL(trackIdentity: "A") == recovered)
        #expect(await source.calls == 2)
        #expect(try files(in: directory).count == 1)
    }

    @Test("confirmed absence is cached only for its track")
    func absence() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = MusicArtworkResponses([.success(nil), .success(Data([2]))])
        let client = MusicAppleScriptClient(artworkLoader: { try await source.load() }, artworkDirectory: directory)
        #expect(try await client.resolvedArtworkURL(trackIdentity: "A") == nil)
        #expect(try await client.resolvedArtworkURL(trackIdentity: "A") == nil)
        let second = try #require(try await client.resolvedArtworkURL(trackIdentity: "B"))
        #expect(try Data(contentsOf: second) == Data([2]))
        #expect(await source.calls == 2)
    }

    @Test("missing or failed artwork does not orphan the previous file", arguments: [false, true])
    func cleansPreviousFile(failure: Bool) async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let middle: Result<Data?, Error> = failure ? .failure(URLError(.timedOut)) : .success(nil)
        let source = MusicArtworkResponses([.success(Data([1])), middle, .success(Data([3]))])
        let client = MusicAppleScriptClient(artworkLoader: { try await source.load() }, artworkDirectory: directory)
        let first = try #require(try await client.resolvedArtworkURL(trackIdentity: "A"))
        #expect(try await client.resolvedArtworkURL(trackIdentity: "B") == nil)
        #expect(!FileManager.default.fileExists(atPath: first.path))
        #expect(try files(in: directory).isEmpty)
        let third = try #require(try await client.resolvedArtworkURL(trackIdentity: "C"))
        #expect(!FileManager.default.fileExists(atPath: first.path))
        #expect(try Data(contentsOf: third) == Data([3]))
        #expect(try files(in: directory) == [third.lastPathComponent])
    }

    @Test("thrown cancellation is not cached and the next call can succeed")
    func thrownCancellation() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = MusicArtworkResponses([.failure(CancellationError()), .success(Data([2]))])
        let client = MusicAppleScriptClient(artworkLoader: { try await source.load() }, artworkDirectory: directory)
        await #expect(throws: CancellationError.self) {
            try await client.resolvedArtworkURL(trackIdentity: "A")
        }
        let recovered = try #require(try await client.resolvedArtworkURL(trackIdentity: "A"))
        #expect(try Data(contentsOf: recovered) == Data([2]))
        #expect(await source.calls == 2)
    }

    @Test("late data from a canceled lookup preserves the previous cache and file")
    func lateCancellation() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = SuspendedMusicArtwork()
        let client = MusicAppleScriptClient(artworkLoader: { try await source.load() }, artworkDirectory: directory)
        let firstTask = Task { try await client.resolvedArtworkURL(trackIdentity: "A") }
        await source.waitForCall(1)
        await source.complete(1, with: Data([1]))
        let first = try #require(try await firstTask.value)

        let cancelled = Task { try await client.resolvedArtworkURL(trackIdentity: "B") }
        await source.waitForCall(2)
        cancelled.cancel()
        await source.complete(2, with: Data([2]))
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        #expect(try Data(contentsOf: first) == Data([1]))
        #expect(try await client.resolvedArtworkURL(trackIdentity: "A") == first)
        #expect(try files(in: directory) == [first.lastPathComponent])

        let recovered = Task { try await client.resolvedArtworkURL(trackIdentity: "B") }
        await source.waitForCall(3)
        await source.complete(3, with: Data([3]))
        let second = try #require(try await recovered.value)
        #expect(try Data(contentsOf: second) == Data([3]))
        #expect(try files(in: directory) == [second.lastPathComponent])
    }

    @Test("a write failure remains retryable without polling the artwork source repeatedly")
    func writeFailure() async throws {
        let parent = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        let directory = parent.appendingPathComponent("temporarily-unavailable")
        let source = MusicArtworkResponses([.success(Data([1])), .success(Data([2]))])
        let clock = MusicArtworkClock()
        let client = MusicAppleScriptClient(artworkLoader: { try await source.load() },
                                            artworkDirectory: directory, artworkTime: { clock.now })
        #expect(try await client.resolvedArtworkURL(trackIdentity: "A") == nil)
        #expect(try await client.resolvedArtworkURL(trackIdentity: "A") == nil)
        #expect(await source.calls == 1)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        clock.advance(5)
        let recovered = try #require(try await client.resolvedArtworkURL(trackIdentity: "A"))
        #expect(try Data(contentsOf: recovered) == Data([2]))
        #expect(await source.calls == 2)
        #expect(try files(in: directory) == [recovered.lastPathComponent])
    }

    @Test("a late older result cannot replace or delete a newer track's artwork")
    func lateOlderResult() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = SuspendedMusicArtwork()
        let client = MusicAppleScriptClient(artworkLoader: { try await source.load() }, artworkDirectory: directory)
        let first = Task { try await client.resolvedArtworkURL(trackIdentity: "A") }
        await source.waitForCall(1)
        let second = Task { try await client.resolvedArtworkURL(trackIdentity: "B") }
        await source.waitForCall(2)
        await source.complete(2, with: Data([2]))
        let current = try #require(try await second.value)
        await source.complete(1, with: Data([1]))
        await #expect(throws: CancellationError.self) { try await first.value }
        #expect(try Data(contentsOf: current) == Data([2]))
        #expect(try await client.resolvedArtworkURL(trackIdentity: "B") == current)
        #expect(try files(in: directory) == [current.lastPathComponent])
    }

    @Test("separate clients never overwrite or remove each other's temporary artwork")
    func separateOwnership() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = MusicAppleScriptClient(artworkLoader: { Data([1]) }, artworkDirectory: directory)
        let second = MusicAppleScriptClient(artworkLoader: { Data([2]) }, artworkDirectory: directory)
        let firstURL = try #require(try await first.resolvedArtworkURL(trackIdentity: "A"))
        let secondURL = try #require(try await second.resolvedArtworkURL(trackIdentity: "A"))
        #expect(firstURL != secondURL)
        _ = try await first.resolvedArtworkURL(trackIdentity: "B")
        #expect(try Data(contentsOf: secondURL) == Data([2]))
        #expect(try files(in: directory).count == 2)
    }

    @Test("a failed deletion retains its owner and blocks additional files until recovery")
    func deletionFailure() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let deletion = MusicArtworkDeletion()
        let clock = MusicArtworkClock()
        let client = MusicAppleScriptClient(artworkLoader: { Data([1]) }, artworkDirectory: directory,
                                            artworkTime: { clock.now }, removeArtworkFile: { try deletion.remove($0) })
        let first = try #require(try await client.resolvedArtworkURL(trackIdentity: "A"))
        deletion.shouldFail = true
        for identity in ["B", "C", "D"] {
            #expect(try await client.resolvedArtworkURL(trackIdentity: identity) == nil)
            #expect(try files(in: directory) == [first.lastPathComponent])
        }
        deletion.shouldFail = false
        clock.advance(5)
        let recovered = try #require(try await client.resolvedArtworkURL(trackIdentity: "D"))
        #expect(try files(in: directory) == [recovered.lastPathComponent])
        #expect(!FileManager.default.fileExists(atPath: first.path))
    }

    @Test("a cache hit supersedes a pending request for another track")
    func cacheHitSupersedesPendingRequest() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = SuspendedMusicArtwork()
        let client = MusicAppleScriptClient(artworkLoader: { try await source.load() }, artworkDirectory: directory)
        let first = Task { try await client.resolvedArtworkURL(trackIdentity: "A") }
        await source.waitForCall(1)
        await source.complete(1, with: Data([1]))
        let current = try #require(try await first.value)
        let pending = Task { try await client.resolvedArtworkURL(trackIdentity: "B") }
        await source.waitForCall(2)
        #expect(try await client.resolvedArtworkURL(trackIdentity: "A") == current)
        await source.complete(2, with: Data([2]))
        await #expect(throws: CancellationError.self) { try await pending.value }
        #expect(try Data(contentsOf: current) == Data([1]))
        #expect(try files(in: directory) == [current.lastPathComponent])
    }

    @Test("an already removed owned file does not prevent a later replacement")
    func externallyRemovedFile() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = MusicAppleScriptClient(artworkLoader: { Data([1]) }, artworkDirectory: directory)
        let first = try #require(try await client.resolvedArtworkURL(trackIdentity: "A"))
        try FileManager.default.removeItem(at: first)
        let second = try #require(try await client.resolvedArtworkURL(trackIdentity: "B"))
        #expect(try files(in: directory) == [second.lastPathComponent])
    }

    @Test("the response decoder distinguishes tagged absence from malformed or empty results")
    func responseShape() throws {
        let absent = NSAppleEventDescriptor.list()
        absent.insert(NSAppleEventDescriptor(boolean: false), at: 1)
        #expect(try MusicAppleScriptClient.artworkData(from: absent) == nil)
        let explicitFalse = NSAppleEventDescriptor.list()
        explicitFalse.insert(try #require(NSAppleEventDescriptor(descriptorType: typeFalse, data: Data())), at: 1)
        #expect(try MusicAppleScriptClient.artworkData(from: explicitFalse) == nil)

        let trueTag = try #require(NSAppleEventDescriptor(descriptorType: typeTrue, data: Data()))
        for tag in [NSAppleEventDescriptor(boolean: true), trueTag] {
            let present = NSAppleEventDescriptor.list()
            present.insert(tag, at: 1)
            present.insert(try #require(NSAppleEventDescriptor(descriptorType: typePict, data: Data([1, 2]))), at: 2)
            #expect(try MusicAppleScriptClient.artworkData(from: present) == Data([1, 2]))
        }
        let noBytes = NSAppleEventDescriptor.list()
        noBytes.insert(NSAppleEventDescriptor(boolean: true), at: 1)
        noBytes.insert(try #require(NSAppleEventDescriptor(descriptorType: typePict, data: Data())), at: 2)
        let wrongTag = NSAppleEventDescriptor.list()
        wrongTag.insert(NSAppleEventDescriptor(string: "false"), at: 1)
        let absentWithExtra = NSAppleEventDescriptor.list()
        absentWithExtra.insert(NSAppleEventDescriptor(boolean: false), at: 1)
        absentWithExtra.insert(NSAppleEventDescriptor(string: "extra"), at: 2)
        for invalid in [NSAppleEventDescriptor.list(), noBytes, wrongTag, absentWithExtra] {
            #expect(throws: SpotifyPlaybackError.self) { try MusicAppleScriptClient.artworkData(from: invalid) }
        }
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func files(in directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .map(\.lastPathComponent)
    }
}

private actor MusicArtworkResponses {
    var outcomes: [Result<Data?, Error>]
    private(set) var calls = 0
    init(_ outcomes: [Result<Data?, Error>]) { self.outcomes = outcomes }
    func load() throws -> Data? {
        calls += 1
        guard !outcomes.isEmpty else { throw URLError(.badServerResponse) }
        return try outcomes.removeFirst().get()
    }
}

private final class MusicArtworkClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: TimeInterval = 0
    var now: TimeInterval { lock.withLock { value } }
    func advance(_ seconds: TimeInterval) { lock.withLock { value += seconds } }
}

private final class MusicArtworkDeletion: @unchecked Sendable {
    private let lock = NSLock()
    private var failure = false
    var shouldFail: Bool {
        get { lock.withLock { failure } }
        set { lock.withLock { failure = newValue } }
    }
    func remove(_ url: URL) throws {
        if shouldFail { throw CocoaError(.fileWriteNoPermission) }
        try FileManager.default.removeItem(at: url)
    }
}

private actor SuspendedMusicArtwork {
    private var calls = 0
    private var pending: [Int: CheckedContinuation<Data?, Error>] = [:]
    private var observers: [Int: CheckedContinuation<Void, Never>] = [:]

    func load() async throws -> Data? {
        calls += 1
        let call = calls
        return try await withCheckedThrowingContinuation { continuation in
            pending[call] = continuation
            observers.removeValue(forKey: call)?.resume()
        }
    }

    func waitForCall(_ call: Int) async {
        if calls >= call { return }
        await withCheckedContinuation { observers[call] = $0 }
    }

    func complete(_ call: Int, with data: Data?) {
        pending.removeValue(forKey: call)?.resume(returning: data)
    }
}
