import Sparkle

@MainActor
final class SparkleUpdaterController {
    static let shared = SparkleUpdaterController()

    private let controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
