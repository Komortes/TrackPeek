import AppKit
import CoreFoundation
import CoreServices
import Darwin
import Foundation

private let allowedTargets = Set(["com.spotify.client", "com.apple.Music"])

private func permissionStatus(
    for bundleIdentifier: String,
    askUserIfNeeded: Bool = false
) -> OSStatus {
    precondition(!Thread.isMainThread)
    guard let application = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first,
          !application.isTerminated else { return OSStatus(procNotFound) }
    let target = NSAppleEventDescriptor(processIdentifier: application.processIdentifier)
    return AEDeterminePermissionToAutomateTarget(
        target.aeDesc,
        AEEventClass(typeWildCard),
        AEEventID(typeWildCard),
        askUserIfNeeded
    )
}

private func failure(_ request: AppleScriptRequest, number: Int, message: String) -> AppleScriptResponse {
    AppleScriptResponse(
        id: request.id,
        kind: .result,
        descriptor: nil,
        errorNumber: number,
        errorMessage: String(message.prefix(2_048))
    )
}

private func process(_ request: AppleScriptRequest) throws -> AppleScriptResponse {
    guard request.version == 1,
          !request.source.isEmpty,
          request.source.utf8.count <= AppleScriptIPC.maximumSourceLength,
          !request.source.contains("\0"),
          (1 ... 60).contains(request.appleEventTimeoutSeconds),
          request.targetBundleIdentifier.map({ allowedTargets.contains($0) }) ?? true else {
        return failure(request, number: Int(paramErr), message: "Некорректный запрос AppleScript")
    }

    // Production callers always supply a known player. Pure executor tests
    // omit it, so they need neither a running player nor Automation access.
    if let target = request.targetBundleIdentifier {
        var permission = permissionStatus(for: target)
        if permission == errAEEventWouldRequireUserConsent {
            // Give the user time to respond before starting the script's
            // short Apple Event timeout. Permission requests stay off main.
            try AppleScriptIPC.write(
                AppleScriptResponse(
                    id: request.id,
                    kind: .permissionPending,
                    descriptor: nil,
                    errorNumber: nil,
                    errorMessage: nil
                ),
                to: STDOUT_FILENO
            )
            permission = permissionStatus(for: target, askUserIfNeeded: true)
        }
        if permission != noErr {
            return failure(
                request,
                number: Int(permission),
                message: permission == OSStatus(errAEEventNotPermitted)
                    ? "Нет разрешения Automation"
                    : "Плеер недоступен"
            )
        }
    }

    return try DispatchQueue.main.sync {
        try autoreleasepool { try executeScript(request) }
    }
}

private func executeScript(_ request: AppleScriptRequest) throws -> AppleScriptResponse {
    // NSAppleScript is main-thread-only. A blocked engine can be killed by
    // TrackPeek without blocking or destabilizing its own main thread.
    precondition(Thread.isMainThread)
    let wrapped = "with timeout of \(request.appleEventTimeoutSeconds) seconds\n\(request.source)\nend timeout"
    guard let script = NSAppleScript(source: wrapped) else {
        return failure(request, number: Int(errOSAScriptError), message: "Не удалось создать AppleScript")
    }
    var errorInfo: NSDictionary?
    let descriptor = script.executeAndReturnError(&errorInfo)
    if let errorInfo {
        return failure(
            request,
            number: errorInfo[NSAppleScript.errorNumber] as? Int ?? Int(errOSAScriptError),
            message: errorInfo[NSAppleScript.errorMessage] as? String ?? "Неизвестная ошибка AppleScript"
        )
    }
    let data = try NSKeyedArchiver.archivedData(withRootObject: descriptor, requiringSecureCoding: true)
    // Leave room for the response envelope within the transport's frame cap.
    guard data.count <= AppleScriptIPC.maximumFrameLength - 4_096 else {
        return failure(request, number: Int(errAEBufferTooSmall), message: "Ответ плеера слишком большой")
    }
    return AppleScriptResponse(
        id: request.id,
        kind: .result,
        descriptor: data,
        errorNumber: nil,
        errorMessage: nil
    )
}

@MainActor private func runHelper() {
    let parentPID = getppid()
    guard parentPID > 1 else { return }
    let parentExit = DispatchSource.makeProcessSource(
        identifier: parentPID,
        eventMask: .exit,
        queue: DispatchQueue(label: "com.trackpeek.script-helper.parent")
    )
    parentExit.setEventHandler { _exit(EXIT_SUCCESS) }
    parentExit.activate()
    // Covers parent exit before the process source was registered.
    guard getppid() == parentPID else { return }
    defer { parentExit.cancel() }

    // Initialize Cocoa's application services on main before background
    // permission checks. The helper presents neither windows nor a Dock icon.
    NSApplication.shared.setActivationPolicy(.prohibited)

    // An installed source keeps the main run loop alive without a timer.
    // LaunchServices and permission preflight can require work on this thread;
    // blocking it with pipe I/O or a semaphore would deadlock that work.
    var context = CFRunLoopSourceContext(
        version: 0,
        info: nil,
        retain: nil,
        release: nil,
        copyDescription: nil,
        equal: nil,
        hash: nil,
        schedule: nil,
        cancel: nil,
        perform: { _ in }
    )
    guard let keepAlive = CFRunLoopSourceCreate(nil, 0, &context) else { return }
    CFRunLoopAddSource(CFRunLoopGetMain(), keepAlive, .defaultMode)
    defer { CFRunLoopRemoveSource(CFRunLoopGetMain(), keepAlive, .defaultMode) }

    DispatchQueue(label: "com.trackpeek.script-helper.ipc", qos: .userInitiated).async {
        defer { _exit(EXIT_SUCCESS) }
        do {
            while let request = try AppleScriptIPC.read(AppleScriptRequest.self, from: STDIN_FILENO) {
                try autoreleasepool {
                    let response = try process(request)
                    try AppleScriptIPC.write(response, to: STDOUT_FILENO)
                }
            }
        } catch {
            // EOF or a malformed/private pipe ends this generation. The app
            // owns recovery and never replays a possibly completed command.
            return
        }
    }
    CFRunLoopRun()
}

runHelper()
