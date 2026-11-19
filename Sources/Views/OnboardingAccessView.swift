import AppKit
import Observation
import SwiftUI

struct OnboardingAccessView: View {
    let source: MediaSourcePreference
    @State private var access = OnboardingAccessCheck(coordinator: .shared)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(String(localized: "Player Access"), systemImage: "lock.shield")
                .font(.subheadline.weight(.semibold))

            Text(String(localized: "TrackPeek controls the player through Apple Events. macOS will ask for permission once."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(String(localized: "Check Access")) { access.check() }
                    .disabled(access.status == .checking)
                if access.status == .denied {
                    Button(String(localized: "Open Permissions")) {
                        access.openPermissions(for: source)
                    }
                }
            }

            statusMessage
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: source) { access.reset() }
        .onDisappear { access.reset() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            access.returnedToApp(for: source)
        }
    }

    @ViewBuilder private var statusMessage: some View {
        switch access.status {
        case .unknown:
            EmptyView()
        case .checking:
            ProgressView().controlSize(.small)
                .accessibilityLabel(String(localized: "Checking connection"))
        case .granted:
            Label(String(localized: "Access granted"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .denied:
            Label(String(localized: "Automation permission is missing"), systemImage: "lock.slash")
                .foregroundStyle(.secondary)
        case .playerNotRunning:
            Label(String(localized: "The player is not running. Permission will be requested later"), systemImage: "info.circle")
                .foregroundStyle(.secondary)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        }
    }
}

@MainActor
@Observable
final class OnboardingAccessCheck {
    enum Status: Equatable {
        case unknown, checking, granted, denied, playerNotRunning
        case failed(String)
    }

    private(set) var status = Status.unknown
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var pendingSettingsReturn: MediaSourcePreference?
    private let probe: @MainActor () async -> Status

    init(probe: @escaping @MainActor () async -> Status) {
        self.probe = probe
    }

    convenience init(coordinator: PlaybackCoordinator) {
        self.init {
            guard !coordinator.isSleeping else { return .unknown }
            // The picker may have changed before the defaults notification arrived.
            coordinator.sourcePreferenceDidChange()
            let model = coordinator.model
            await model.refresh()
            switch model.availability {
            case .ready, .nothingPlaying: return .granted
            case .automationDenied: return .denied
            case .spotifyNotRunning: return .playerNotRunning
            case .unavailable: return .failed(model.statusText)
            case .loading: return .unknown
            }
        }
    }

    @discardableResult
    func check() -> Task<Void, Never> {
        reset()
        status = .checking
        let task = Task { [weak self, probe] in
            guard !Task.isCancelled else { return }
            let result = await probe()
            guard !Task.isCancelled else { return }
            self?.status = result
            self?.task = nil
        }
        self.task = task
        return task
    }

    func reset() {
        task?.cancel()
        task = nil
        pendingSettingsReturn = nil
        status = .unknown
    }

    func openPermissions(for source: MediaSourcePreference, open: @MainActor () -> Bool = PlayerAppLauncher.openAutomationSettings) {
        guard status == .denied, open() else { return }
        pendingSettingsReturn = source
    }

    @discardableResult
    func returnedToApp(for source: MediaSourcePreference) -> Task<Void, Never>? {
        guard pendingSettingsReturn == source else { return nil }
        return check()
    }
}
