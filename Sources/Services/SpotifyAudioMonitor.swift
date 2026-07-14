import AppKit
import Observation

private final class SpotifyAudioAnalyzerEngine: @unchecked Sendable {
    private let queue = DispatchQueue(
        label: "com.trackpeek.spotify-spectrum",
        qos: .userInteractive
    )
    private let analyzer = TPAudioLevelAnalyzer()

    private var source: DispatchSourceTimer?
    private var requestedProcessIdentifier: pid_t?
    private var connectedProcessIdentifier: pid_t?
    private var retryAfter = 0.0
    private var lastPublishedSpectrum: AudioSpectrum?

    func start(onSpectrum: @escaping @Sendable (AudioSpectrum) -> Void) {
        queue.async { [self] in
            guard source == nil else { return }

            let source = DispatchSource.makeTimerSource(queue: queue)
            source.schedule(
                deadline: .now(),
                repeating: .milliseconds(33),
                leeway: .milliseconds(4)
            )
            source.setEventHandler { [weak self] in
                self?.sample(onSpectrum: onSpectrum)
            }
            self.source = source
            source.resume()
        }
    }

    func setProcessIdentifier(_ processIdentifier: pid_t?) {
        queue.async { [self] in
            requestedProcessIdentifier = processIdentifier
        }
    }

    func stop() {
        queue.async { [self] in
            source?.setEventHandler {}
            source?.cancel()
            source = nil
            analyzer.stop()
            requestedProcessIdentifier = nil
            connectedProcessIdentifier = nil
            lastPublishedSpectrum = nil
        }
    }

    private func sample(
        onSpectrum: @escaping @Sendable (AudioSpectrum) -> Void
    ) {
        let now = CFAbsoluteTimeGetCurrent()
        let processChanged = requestedProcessIdentifier != connectedProcessIdentifier

        if processChanged {
            analyzer.stop()
            connectedProcessIdentifier = requestedProcessIdentifier
            retryAfter = 0
        }

        if !analyzer.isRunning, now >= retryAfter,
           let processIdentifier = requestedProcessIdentifier {
            do {
                try analyzer.start(forProcessIdentifier: processIdentifier)
            } catch {
                retryAfter = now + 1
            }
        }

        let spectrum: AudioSpectrum = analyzer.isRunning
            ? AudioSpectrum(values: analyzer.currentLevels().map(\.doubleValue))
            : .resting
        guard spectrum != lastPublishedSpectrum else { return }

        lastPublishedSpectrum = spectrum
        onSpectrum(spectrum)
    }
}

@MainActor
@Observable
final class SpotifyAudioMonitor: NSObject {
    private(set) var spectrum = AudioSpectrum.resting

    @ObservationIgnored private let engine = SpotifyAudioAnalyzerEngine()
    @ObservationIgnored private var processTimer: Timer?

    func start() {
        guard processTimer == nil else { return }
        guard #available(macOS 14.2, *) else { return }
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        engine.start { [weak self] spectrum in
            DispatchQueue.main.async { [weak self] in
                self?.spectrum = spectrum
            }
        }
        synchronizeSpotifyProcess()
        processTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(processTimerDidFire),
            userInfo: nil,
            repeats: true
        )
        processTimer?.tolerance = 0.1
    }

    func stop() {
        processTimer?.invalidate()
        processTimer = nil
        engine.stop()
        spectrum = .resting
    }

    @objc private func processTimerDidFire() {
        synchronizeSpotifyProcess()
    }

    private func synchronizeSpotifyProcess() {
        let spotifyPID = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.spotify.client"
        ).first?.processIdentifier
        engine.setProcessIdentifier(spotifyPID)
    }
}
