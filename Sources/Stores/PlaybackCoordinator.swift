import Foundation
import Observation

/// Единственный источник playback-состояния для всех поверхностей
/// (menu bar, popover, чёлка/виджет): одна модель, один цикл опроса,
/// один аудиомонитор и один кэш текстов. Раньше каждая поверхность
/// держала собственную модель и опрашивала AppleScript независимо.
@MainActor
final class PlaybackCoordinator {
    static let shared = PlaybackCoordinator()

    let model = SpotifySpikeModel()
    let audioMonitor = SpotifyAudioMonitor()
    let lyricsStore = LyricsStore()

    private var refreshTask: Task<Void, Never>?

    private init() {}

    /// Menu bar существует всегда, поэтому опрос идёт всё время работы
    /// приложения; интервал зависит от того, играет ли музыка.
    func start() {
        guard refreshTask == nil else { return }
        refreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await model.refresh()
                guard !Task.isCancelled else { return }
                if model.track?.isPlaying == true {
                    audioMonitor.setActiveSource(model.activeSource)
                    audioMonitor.start()
                } else {
                    audioMonitor.stop()
                }

                let interval = model.track?.isPlaying == true ? 2.0 : 4.0
                try? await Task.sleep(for: .milliseconds(Int64(interval * 1_000)))
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        audioMonitor.stop()
    }
}
