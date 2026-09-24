import AppKit
import Observation

/// Owns the only poll schedule. Reads from other UI surfaces are coalesced by
/// the model and reschedule this timer when they complete.
@MainActor
@Observable
final class PlaybackCoordinator: NSObject {
    static let shared = PlaybackCoordinator()

    let model: SpotifySpikeModel
    let audioMonitor: SpotifyAudioMonitor
    let lyricsStore: LyricsStore
    private(set) var resourceUsageMode = ResourceUsageMode.fallback
    private(set) var systemLowPowerMode = false
    var isSavingResources: Bool { resourceUsageMode.isSaving(lowPowerMode: systemLowPowerMode) }
    @ObservationIgnored private let lowPowerMode: () -> Bool
    private(set) var isSleeping = false
    private(set) var nextRefreshDate: Date?

    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var scheduleGeneration = 0
    @ObservationIgnored private var isStarted = false
    @ObservationIgnored private let observesSystemEvents: Bool
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var sourcePreference: String?

    init(
        model: SpotifySpikeModel = SpotifySpikeModel(),
        audioMonitor: SpotifyAudioMonitor = SpotifyAudioMonitor(),
        lyricsStore: LyricsStore = LyricsStore(),
        defaults: UserDefaults = .standard,
        observesSystemEvents: Bool = true,
        lowPowerMode: @escaping () -> Bool = { ProcessInfo.processInfo.isLowPowerModeEnabled }
    ) {
        self.lowPowerMode = lowPowerMode
        self.model = model
        self.audioMonitor = audioMonitor
        self.lyricsStore = lyricsStore
        self.defaults = defaults
        self.observesSystemEvents = observesSystemEvents
        super.init()
        model.onRefreshCompleted = { [weak self] in self?.refreshCompleted() }
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        isSleeping = false
        resourcePolicyDidChange()
        sourcePreference = defaults.string(forKey: MediaSourcePreference.storageKey)
        if observesSystemEvents {
            NotificationCenter.default.addObserver(self, selector: #selector(powerStateChanged), name: .NSProcessInfoPowerStateDidChange, object: nil)
            let workspace = NSWorkspace.shared.notificationCenter
            workspace.addObserver(self, selector: #selector(workspaceChanged), name: NSWorkspace.willSleepNotification, object: nil)
            workspace.addObserver(self, selector: #selector(workspaceChanged), name: NSWorkspace.didWakeNotification, object: nil)
            workspace.addObserver(self, selector: #selector(workspaceChanged), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
            workspace.addObserver(self, selector: #selector(workspaceChanged), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(preferencesChanged), name: UserDefaults.didChangeNotification, object: defaults)
        }
        requestRefresh()
    }

    func stop() {
        isStarted = false
        cancelSchedule()
        model.invalidate()
        audioMonitor.stop()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func requestRefresh() {
        guard isStarted, !isSleeping else { return }
        schedule(after: 0)
    }

    func suspendForSleep() {
        guard isStarted else { return }
        isSleeping = true
        cancelSchedule()
        model.invalidate()
        audioMonitor.stop()
    }

    func resumeAfterWake() {
        guard isStarted else { return }
        isSleeping = false
        resourcePolicyDidChange()
        model.invalidate()
        requestRefresh()
    }

    func sourcePreferenceDidChange() {
        let preference = defaults.string(forKey: MediaSourcePreference.storageKey)
        guard isStarted, preference != sourcePreference else { return }
        sourcePreference = preference
        cancelSchedule()
        model.invalidate(clearTrack: true)
        audioMonitor.stop()
        requestRefresh()
    }

    func resourcePolicyDidChange() {
        guard isStarted else { return }
        let wasSaving = isSavingResources
        resourceUsageMode = ResourceUsageMode(rawValue: defaults.string(forKey: ResourceUsageMode.storageKey) ?? "") ?? .fallback
        systemLowPowerMode = lowPowerMode()
        audioMonitor.setResourceSaving(isSavingResources)
        guard wasSaving != isSavingResources, !isSleeping,
              nextRefreshDate != nil, !model.isRefreshing else { return }
        if let delay = backgroundRefreshDelay { schedule(after: delay) }
    }

    private var backgroundRefreshDelay: TimeInterval? {
        ResourceUsageMode.pollDelay(model.nextRefreshDelay, availability: model.availability, saving: isSavingResources)
    }

    private func refreshCompleted() {
        guard isStarted, !isSleeping else { return }
        if model.availability == .ready, model.track?.isPlaying == true {
            audioMonitor.setActiveSource(model.activeSource)
            audioMonitor.start()
        } else {
            audioMonitor.stop()
        }
        cancelSchedule()
        if let delay = backgroundRefreshDelay { schedule(after: delay) }
    }

    private func cancelSchedule() {
        scheduleGeneration &+= 1
        refreshTask?.cancel()
        refreshTask = nil
        nextRefreshDate = nil
    }

    private func schedule(after delay: TimeInterval) {
        cancelSchedule()
        let generation = scheduleGeneration
        nextRefreshDate = delay > 0 ? Date().addingTimeInterval(delay) : nil
        refreshTask = Task { [weak self] in
            do {
                if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
                try Task.checkCancellation()
            } catch { return }
            guard let self, self.isStarted, !self.isSleeping,
                  generation == self.scheduleGeneration else { return }
            self.nextRefreshDate = nil
            await self.model.refresh()
        }
    }

    @objc nonisolated private func preferencesChanged(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.sourcePreferenceDidChange()
            self?.resourcePolicyDidChange()
        }
    }

    @objc nonisolated private func powerStateChanged(_ notification: Notification) {
        Task { @MainActor [weak self] in self?.resourcePolicyDidChange() }
    }

    @objc nonisolated private func workspaceChanged(_ notification: Notification) {
        let name = notification.name
        let bundle = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
        Task { @MainActor [weak self] in
            guard let self, self.isStarted else { return }
            switch name {
            case NSWorkspace.willSleepNotification:
                self.suspendForSleep()
            case NSWorkspace.didWakeNotification:
                self.resumeAfterWake()
            default:
                guard bundle == PlaybackSource.spotify.bundleIdentifier
                    || bundle == PlaybackSource.appleMusic.bundleIdentifier else { return }
                self.cancelSchedule()
                self.model.invalidate(clearTrack: name == NSWorkspace.didTerminateApplicationNotification
                    && bundle == self.model.activeSource?.bundleIdentifier)
                self.audioMonitor.stop()
                self.requestRefresh()
            }
        }
    }
}
