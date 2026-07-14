import AppKit
import Observation

/// Manages the optional prev/play-pause/next `NSStatusItem`s shown next to the
/// primary `MenuBarExtra` when the user opts in via Settings. Kept separate
/// from the primary status item because SwiftUI's `MenuBarExtra` only supports
/// one click target — independent buttons need their own status items.
@MainActor
@Observable
final class MenuBarControlsController: NSObject {
    let model = SpotifySpikeModel()
    let audioMonitor = SpotifyAudioMonitor()

    private var previousItem: NSStatusItem?
    private var playPauseItem: NSStatusItem?
    private var nextItem: NSStatusItem?
    private var refreshTask: Task<Void, Never>?
    private var isEnabled = false

    func start() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidChange),
            name: UserDefaults.didChangeNotification,
            object: UserDefaults.standard
        )
        synchronize()
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
        teardown()
    }

    @objc nonisolated private func preferencesDidChange(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.synchronize()
        }
    }

    private func synchronize() {
        let enabled = UserDefaults.standard.bool(forKey: MenuBarPreferences.controlsEnabledKey)
        guard enabled != isEnabled else { return }
        isEnabled = enabled

        if enabled {
            createStatusItemsIfNeeded()
            audioMonitor.start()
            startRefreshTask()
        } else {
            teardown()
        }
    }

    private func teardown() {
        refreshTask?.cancel()
        refreshTask = nil
        audioMonitor.stop()

        for item in [previousItem, playPauseItem, nextItem] {
            if let item {
                NSStatusBar.system.removeStatusItem(item)
            }
        }
        previousItem = nil
        playPauseItem = nil
        nextItem = nil
    }

    private func createStatusItemsIfNeeded() {
        guard previousItem == nil else { return }

        // NSStatusBar places each newly added item to the LEFT of the ones
        // already there, so items must be created in reverse of the desired
        // left-to-right reading order (previous, play/pause, next).
        let next = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        next.button?.image = NSImage(
            systemSymbolName: "forward.fill",
            accessibilityDescription: "Следующий трек"
        )
        next.button?.target = self
        next.button?.action = #selector(nextTapped)

        let playPause = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        playPause.button?.image = NSImage(
            systemSymbolName: "play.fill",
            accessibilityDescription: "Играть"
        )
        playPause.button?.target = self
        playPause.button?.action = #selector(playPauseTapped)

        let previous = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        previous.button?.image = NSImage(
            systemSymbolName: "backward.fill",
            accessibilityDescription: "Предыдущий трек"
        )
        previous.button?.target = self
        previous.button?.action = #selector(previousTapped)

        previousItem = previous
        playPauseItem = playPause
        nextItem = next
    }

    @objc private func previousTapped() {
        Task { await model.previousTrack() }
    }

    @objc private func playPauseTapped() {
        Task { await model.togglePlayback() }
    }

    @objc private func nextTapped() {
        Task { await model.nextTrack() }
    }

    private func startRefreshTask() {
        guard refreshTask == nil else { return }

        refreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await model.refresh()
                updateButtonAppearance()

                let interval = model.track?.isPlaying == true ? 2.0 : 4.0
                try? await Task.sleep(for: .milliseconds(Int64(interval * 1_000)))
            }
        }
    }

    private func updateButtonAppearance() {
        let isPlaying = model.track?.isPlaying == true
        let isAvailable = model.availability == .ready

        playPauseItem?.button?.image = NSImage(
            systemSymbolName: isPlaying ? "pause.fill" : "play.fill",
            accessibilityDescription: isPlaying ? "Пауза" : "Играть"
        )

        for item in [previousItem, playPauseItem, nextItem] {
            item?.button?.appearsDisabled = !isAvailable
            item?.button?.isEnabled = isAvailable
        }
    }
}
