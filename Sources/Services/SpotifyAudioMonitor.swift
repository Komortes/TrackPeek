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
    /// Сглаженный уровень на каждую полосу — раздельные коэффициенты для
    /// атаки/спада не дают волне дёргаться, когда очередная сырая выборка
    /// приходит быстрее, чем успела доиграть предыдущая SwiftUI-анимация.
    private var smoothedLevels: [Double]?
    private static let attackCoefficient = 0.55
    private static let releaseCoefficient = 0.22

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
            smoothedLevels = nil
        }

        if !analyzer.isRunning, now >= retryAfter,
           let processIdentifier = requestedProcessIdentifier {
            do {
                try analyzer.start(forProcessIdentifier: processIdentifier)
            } catch {
                retryAfter = now + 1
            }
        }

        let spectrum: AudioSpectrum
        if analyzer.isRunning {
            let rawLevels = analyzer.currentLevels().map(\.doubleValue)
            spectrum = AudioSpectrum(values: smoothed(rawLevels))
        } else {
            smoothedLevels = nil
            spectrum = .resting
        }
        guard spectrum != lastPublishedSpectrum else { return }

        lastPublishedSpectrum = spectrum
        onSpectrum(spectrum)
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
    private(set) var spectrum = AudioSpectrum.resting

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

    var isAnalysisRequested: Bool { playbackRequested && !consumers.isEmpty }

    deinit { engine.stop() }

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
        if isAnalysisRequested { startEngine() } else { stopEngine() }
    }

    private func startEngine() {
        guard processTimer == nil else { return }
        guard #available(macOS 14.2, *) else { return }
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        generation &+= 1
        let generation = generation
        engine.start { [weak self] spectrum in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == generation, self.isAnalysisRequested else { return }
                self.spectrum = spectrum
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
