import Darwin
import Foundation

struct AppleScriptRequest: Codable, Sendable {
    var version: Int = 1
    let id: UUID
    let source: String
    let targetBundleIdentifier: String?
    var appleEventTimeoutSeconds: Int = 5
}

struct AppleScriptResponse: Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case result
        case permissionPending
    }

    var version: Int = 1
    let id: UUID
    let kind: Kind
    let descriptor: Data?
    let errorNumber: Int?
    let errorMessage: String?
}

/// The private pipe carries one bounded binary property list per frame.
/// Callers serialize writes and keep blocking I/O off their supervisor queue.
enum AppleScriptIPC {
    static let maximumFrameLength = 16 * 1024 * 1024
    static let maximumSourceLength = 64 * 1024

    enum Failure: Error {
        case invalidFrameLength
        case truncatedFrame
        case systemCall(Int32)
    }

    static func read<T: Decodable>(_ type: T.Type, from fd: Int32) throws -> T? {
        guard let header = try readBytes(4, from: fd, allowCleanEOF: true) else {
            return nil
        }
        let length = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard length > 0, length <= UInt32(maximumFrameLength) else {
            throw Failure.invalidFrameLength
        }
        guard let payload = try readBytes(Int(length), from: fd, allowCleanEOF: false) else {
            throw Failure.truncatedFrame
        }
        return try PropertyListDecoder().decode(type, from: payload)
    }

    static func write<T: Encodable>(_ value: T, to fd: Int32) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let payload = try encoder.encode(value)
        guard !payload.isEmpty, payload.count <= maximumFrameLength else {
            throw Failure.invalidFrameLength
        }

        // A vanished reader is an ordinary EPIPE error, never a signal that
        // terminates TrackPeek. This applies only to our private pipe fd.
        while fcntl(fd, F_SETNOSIGPIPE, 1) == -1 {
            if errno != EINTR { throw Failure.systemCall(errno) }
        }
        let length = UInt32(payload.count)
        let header = Data([
            UInt8(truncatingIfNeeded: length >> 24),
            UInt8(truncatingIfNeeded: length >> 16),
            UInt8(truncatingIfNeeded: length >> 8),
            UInt8(truncatingIfNeeded: length),
        ])
        try writeBytes(header, to: fd)
        try writeBytes(payload, to: fd)
    }

    private static func readBytes(
        _ count: Int,
        from fd: Int32,
        allowCleanEOF: Bool
    ) throws -> Data? {
        var data = Data(count: count)
        let complete = try data.withUnsafeMutableBytes { buffer in
            var offset = 0
            while offset < count {
                let received = Darwin.read(fd, buffer.baseAddress!.advanced(by: offset), count - offset)
                if received > 0 {
                    offset += received
                } else if received == 0 {
                    if allowCleanEOF && offset == 0 { return false }
                    throw Failure.truncatedFrame
                } else if errno != EINTR {
                    throw Failure.systemCall(errno)
                }
            }
            return true
        }
        return complete ? data : nil
    }

    private static func writeBytes(_ data: Data, to fd: Int32) throws {
        try data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let sent = Darwin.write(fd, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                if sent > 0 {
                    offset += sent
                } else if sent == 0 {
                    throw Failure.systemCall(EIO)
                } else if errno != EINTR {
                    throw Failure.systemCall(errno)
                }
            }
        }
    }
}
