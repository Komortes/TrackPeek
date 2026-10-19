import AppKit
import Observation

enum AudioAnalysisStatus: Equatable, Sendable {
    case paused, notNeeded, resourceSaving, starting, waitingForAudio, running, stalled, sourceUnavailable, unsupported
    case failed(Int)

    var description: String {
        switch self {
        case .resourceSaving: String(localized: "Stopped: saving resources")
        case .paused: String(localized: "Stopped: nothing is playing")
        case .notNeeded: String(localized: "Stopped: no visible view needs audio")
        case .starting: String(localized: "Connecting to the audio stream")
        case .waitingForAudio: String(localized: "Waiting for audio data")
        case .running: String(localized: "Running")
        case .stalled: String(localized: "No audio data: reconnecting")
        case .sourceUnavailable: String(localized: "The player process is not running")
        case .unsupported: String(localized: "Requires macOS 14.2 or later")
        case .failed(let code): String(localized: "Audio capture error (\(code))")
        }
    }
}

private final class SpotifyAudioAnalyzerEngine: @unchecked Sendable {
    private let queue = DispatchQueue(
        label: "com.trackpeek.spotify-spectrum",
        qos: .userInteractive
    )
    private let analyzer = TPAudioLevelAnalyzer()

    private var source: DispatchSourceTimer?
    private var requestedProcessIdentifier: pid_t?
    private var connectedProcessIdentifier: pid_t?
    private var health = AudioCaptureHealth()
    private var lastPublishedSpectrum: AudioSpectrum?
    private var lastPublishedStatus: AudioAnalysisStatus?
    private var lastErrorCode: Int?
    /// Сглаженный уровень на каждую полосу — раздельные коэффициенты для
    /// атаки/спада не дают волне дёргаться, когда очередная сырая выборка
    /// приходит быстрее, чем успела доиграть предыдущая SwiftUI-анимация.
    private var smoothedLevels: [Double]?
    private static let attackCoefficient = 0.55
    private static let releaseCoefficient = 0.22

    func start(onSpectrum: @escaping @Sendable (AudioSpectrum, AudioAnalysisStatus) -> Void) {
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
            lastPublishedStatus = nil
            health.reset()
            lastErrorCode = nil
            smoothedLevels = nil
        }
    }

    private func sample(
        onSpectrum: @escaping @Sendable (AudioSpectrum, AudioAnalysisStatus) -> Void
    ) {
        let now = ProcessInfo.processInfo.systemUptime
        let processChanged = requestedProcessIdentifier != connectedProcessIdentifier

        if processChanged {
            analyzer.stop()
            connectedProcessIdentifier = requestedProcessIdentifier
            health.reset()
            lastErrorCode = nil
            smoothedLevels = nil
        }

        if !analyzer.isRunning, let processIdentifier = requestedProcessIdentifier,
           health.beginAttempt(at: now) {
            lastErrorCode = nil
            do {
                try analyzer.start(forProcessIdentifier: processIdentifier)
            } catch {
                lastErrorCode = (error as NSError).code
                health.failAttempt(at: ProcessInfo.processInfo.systemUptime)
            }
        }

        if analyzer.isRunning {
            health.observe(sequence: analyzer.analyzedBufferCount, at: ProcessInfo.processInfo.systemUptime)
            if health.phase == .stalled {
                analyzer.stop()
            }
        }

        let spectrum: AudioSpectrum
        if health.phase == .running, analyzer.isRunning {
            let rawLevels = analyzer.currentLevels().map(\.doubleValue)
            spectrum = AudioSpectrum(values: smoothed(rawLevels))
        } else {
            smoothedLevels = nil
            spectrum = .resting
        }
        let status: AudioAnalysisStatus
        if requestedProcessIdentifier == nil { status = .sourceUnavailable }
        else if let lastErrorCode { status = .failed(lastErrorCode) }
        else {
            switch health.phase {
            case .idle: status = .starting
            case .waitingForAudio: status = .waitingForAudio
            case .running: status = .running
            case .stalled: status = .stalled
            }
        }
        guard spectrum != lastPublishedSpectrum || status != lastPublishedStatus else { return }

        if status != lastPublishedStatus {
            // Failed/inactive capture needs retries, not thirty wakeups a second.
            let interval: DispatchTimeInterval = status == .running ? .milliseconds(33) : .seconds(1)
            source?.schedule(deadline: .now() + interval, repeating: interval,
                             leeway: status == .running ? .milliseconds(4) : .milliseconds(100))
        }
        lastPublishedSpectrum = spectrum
        lastPublishedStatus = status
        onSpectrum(spectrum, status)
    }

    /// Экспоненциальное attack/release-сглаживание по каждой полосе: рост
    /// уровня подхватывается быстро, спад — медленнее, как у аналогового
    /// эквалайзера. Без этого резкая пилообразная выборка каждые 33 мс
    /// дёргала волну быстрее, чем успевала доиграть анимация в SwiftUI.
    private func smoothed(_ rawLevels: [Double]) -> [Double] {
        guard var levels = smoothedLevels, levels.count == rawLevels.count else {
            smoothedLevels = rawLevels
            return rawLevels
        }

        for index in rawLevels.indices {
            let raw = rawLevels[index]
            let coefficient = raw > levels[index]
                ? Self.attackCoefficient
                : Self.releaseCoefficient
            levels[index] += (raw - levels[index]) * coefficient
        }

        smoothedLevels = levels
        return levels
    }
}

@MainActor
@Observable
final class SpotifyAudioMonitor: NSObject {
    private(set) var isResourceSaving = false
    private(set) var spectrum = AudioSpectrum.resting
    private(set) var analysisStatus: AudioAnalysisStatus = .paused

    @ObservationIgnored private let engine = SpotifyAudioAnalyzerEngine()
    @ObservationIgnored private var processTimer: Timer?
    /// Плеер, чей аудиопоток анализируется; ставится координатором из
    /// активного источника снапшота. Раньше монитор знал только Spotify,
    /// и на Apple Music эквалайзер оставался неподвижным.
    @ObservationIgnored private var activeBundleIdentifier =
        PlaybackSource.spotify.bundleIdentifier

    @ObservationIgnored private var playbackRequested = false
    @ObservationIgnored private var consumers: Set<UUID> = []
    @ObservationIgnored private var generation = 0

    var isAnalysisRequested: Bool { playbackRequested && !consumers.isEmpty && !isResourceSaving }

    deinit { engine.stop() }

    func setResourceSaving(_ enabled: Bool) {
        guard isResourceSaving != enabled else { return }
        isResourceSaving = enabled
        synchronizeDemand()
    }

    func setConsumer(_ id: UUID, active: Bool) {
        if active { consumers.insert(id) } else { consumers.remove(id) }
        synchronizeDemand()
    }

    func start() {
        playbackRequested = true
        synchronizeDemand()
    }

    func stop() {
        playbackRequested = false
        synchronizeDemand()
    }

    private func synchronizeDemand() {
        if isAnalysisRequested {
            startEngine()
        } else {
            stopEngine()
            analysisStatus = playbackRequested ? (isResourceSaving ? .resourceSaving : .notNeeded) : .paused
        }
    }

    private func startEngine() {
        guard processTimer == nil else { return }
        guard #available(macOS 14.2, *) else {
            analysisStatus = .unsupported
            return
        }
        analysisStatus = .starting
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        generation &+= 1
        let generation = generation
        engine.start { [weak self] spectrum, status in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == generation, self.isAnalysisRequested else { return }
                self.spectrum = spectrum
                self.analysisStatus = status
            }
        }
        synchronizeProcess()
        processTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            MainActor.assumeIsolated { self.synchronizeProcess() }
        }
        processTimer?.tolerance = 0.1
    }

    private func stopEngine() {
        guard processTimer != nil else { return }
        generation &+= 1
        processTimer?.invalidate()
        processTimer = nil
        engine.stop()
        spectrum = .resting
    }

    func retryIfNeeded() {
        stopEngine()
        synchronizeDemand()
    }

    func setActiveSource(_ source: PlaybackSource?) {
        let bundleIdentifier = (source ?? .spotify).bundleIdentifier
        guard bundleIdentifier != activeBundleIdentifier else { return }
        activeBundleIdentifier = bundleIdentifier
        synchronizeProcess()
    }

    private func synchronizeProcess() {
        let pid = NSRunningApplication.runningApplications(
            withBundleIdentifier: activeBundleIdentifier
        ).first?.processIdentifier
        engine.setProcessIdentifier(pid)
    }
}
