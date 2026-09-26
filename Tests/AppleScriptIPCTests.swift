import Darwin
import Foundation
import Testing
@testable import TrackPeek

@Suite("AppleScript private pipe framing")
struct AppleScriptIPCTests {
    @Test("only EOF before a frame is clean; incomplete headers and payloads fail")
    func distinguishesCleanAndTruncatedEOF() throws {
        try withPipe { reader, writer in
            try writer.close()
            let result = try AppleScriptIPC.read(AppleScriptResponse.self, from: reader.fileDescriptor)
            #expect(result == nil)
        }

        let truncatedFrames = [
            Data([0x00, 0x00]), // Only half of the length header.
            Data([0x00, 0x00, 0x00, 0x05, 0x01, 0x02]), // Five bytes promised, two delivered.
        ]
        for bytes in truncatedFrames {
            try withPipe { reader, writer in
                try writer.write(contentsOf: bytes)
                try writer.close()
                do {
                    _ = try AppleScriptIPC.read(AppleScriptResponse.self, from: reader.fileDescriptor)
                    Issue.record("An incomplete frame should throw, not return EOF")
                } catch AppleScriptIPC.Failure.truncatedFrame {
                    // Expected for both a partial header and a partial payload.
                }
            }
        }
    }

    @Test("oversized frame lengths are rejected before reading a payload")
    func rejectsOversizedHeader() throws {
        try withPipe { reader, writer in
            let length = UInt32(AppleScriptIPC.maximumFrameLength + 1)
            let header = Data([
                UInt8(truncatingIfNeeded: length >> 24),
                UInt8(truncatingIfNeeded: length >> 16),
                UInt8(truncatingIfNeeded: length >> 8),
                UInt8(truncatingIfNeeded: length),
            ])
            try writer.write(contentsOf: header)
            try writer.close()
            do {
                _ = try AppleScriptIPC.read(AppleScriptResponse.self, from: reader.fileDescriptor)
                Issue.record("An oversized length should be rejected")
            } catch AppleScriptIPC.Failure.invalidFrameLength {
                // EOF after this header must not be misreported as truncation.
            }
        }
    }

    @Test("a binary frame preserves response metadata and every descriptor byte")
    func binaryFrameRoundTrip() throws {
        try withPipe { reader, writer in
            let original = AppleScriptResponse(
                id: UUID(),
                kind: .result,
                descriptor: Data((0 ... 255).map { UInt8($0) }),
                errorNumber: nil,
                errorMessage: nil
            )
            // This frame is smaller than one pipe buffer, so serial I/O cannot block.
            try AppleScriptIPC.write(original, to: writer.fileDescriptor)
            try writer.close()
            let decoded = try AppleScriptIPC.read(AppleScriptResponse.self, from: reader.fileDescriptor)
            let result = try #require(decoded)
            #expect(result.version == original.version)
            #expect(result.id == original.id)
            #expect(result.kind == original.kind)
            #expect(result.descriptor == original.descriptor)
            #expect(result.errorNumber == nil)
            #expect(result.errorMessage == nil)
            let next = try AppleScriptIPC.read(AppleScriptResponse.self, from: reader.fileDescriptor)
            #expect(next == nil)
        }
    }

    @Test("a vanished pipe reader produces EPIPE without changing process-wide signal handling")
    func vanishedReaderThrowsEPIPE() throws {
        try withPipe { reader, writer in
            let fd = writer.fileDescriptor
            try AppleScriptIPC.write(["warm up private pipe"], to: fd)
            // Fail safely before closing the reader if per-fd suppression regresses.
            // The test never installs a global SIGPIPE handler or ignores signals.
            try #require(fcntl(fd, F_GETNOSIGPIPE) == 1)
            try reader.close()
            do {
                try AppleScriptIPC.write(["reader has exited"], to: fd)
                Issue.record("Writing to a pipe with no reader should throw EPIPE")
            } catch let AppleScriptIPC.Failure.systemCall(code) {
                #expect(code == EPIPE)
            }
        }
    }

    private func withPipe(_ body: (FileHandle, FileHandle) throws -> Void) rethrows {
        let pipe = Pipe()
        defer {
            try? pipe.fileHandleForReading.close()
            try? pipe.fileHandleForWriting.close()
        }
        try body(pipe.fileHandleForReading, pipe.fileHandleForWriting)
    }
}
