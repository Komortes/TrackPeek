import AppKit
import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @AppStorage(MediaSourcePreference.storageKey)
    private var mediaSourceRawValue = MediaSourcePreference.fallback.rawValue

    @AppStorage(OverlayMode.storageKey)
    private var overlayModeRawValue = OverlayMode.fallback.rawValue

    @State private var permissionStatus: PermissionStatus = .unknown
    @State private var permissionTask: Task<Void, Never>?

    @Environment(\.openSettings) private var openSettings

    private static var hasNotchedDisplay: Bool {
        NSScreen.screens.contains {
            $0.auxiliaryTopLeftArea != nil || $0.auxiliaryTopRightArea != nil
        }
    }

    private enum PermissionStatus {
        case unknown
        case checking
        case granted
        case playerNotRunning
        case failed(String)
    }

    private var mediaSource: Binding<MediaSourcePreference> {
        Binding(
            get: { MediaSourcePreference(rawValue: mediaSourceRawValue) ?? .fallback },
            set: { mediaSourceRawValue = $0.rawValue }
        )
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)

                Text(String(localized: "Welcome to TrackPeek"))
                    .font(.title2.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(localized: "A notch and menu bar player for Spotify and Apple Music."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(String(localized: "Music Source"), systemImage: "music.note.list")
                        .font(.subheadline.weight(.semibold))

                    Picker("", selection: mediaSource) {
                        ForEach(MediaSourcePreference.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label(String(localized: "Where to Show the Player"), systemImage: "macbook.and.iphone")
                        .font(.subheadline.weight(.semibold))

                    Picker(String(localized: "Where to Show the Player"), selection: $overlayModeRawValue) {
                        ForEach(OverlayMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Text(
                        OverlayMode(rawValue: overlayModeRawValue)?.summary
                            ?? OverlayMode.fallback.summary
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label(String(localized: "Player Access"), systemImage: "lock.shield")
                        .font(.subheadline.weight(.semibold))

                    Text(String(localized: "TrackPeek controls the player through Apple Events. macOS will ask for permission once."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Button(String(localized: "Check Access"), action: checkPermission)
                            .disabled(isChecking)

                        permissionStatusView
                    }
                }

                LaunchAtLoginToggle()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 10) {
                Button(String(localized: "More Settings")) {
                    let tab: SettingsTab = switch OverlayMode(rawValue: overlayModeRawValue) {
                    case .notch: .notch
                    case .floatingWidget: .widget
                    default: .general
                    }
                    UserDefaults.standard.set(tab.rawValue, forKey: SettingsTab.selectionStorageKey)
                    SettingsWindowPresentation.present(openSettings: openSettings.callAsFunction)
                    onFinish()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(String(localized: "Done")) {
                    onFinish()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 380)
        .onAppear {
            // Предвыбор поверхности по железу (§21.2): вырез → чёлка,
            // иначе виджет Mini Bar. Не перетираем уже сделанный выбор.
            // Также пропускаем предвыбор, если онбординг уже был завершён.
            guard
                !UserDefaults.standard.bool(forKey: OnboardingWindowController.completedKey),
                OverlayMode(rawValue: overlayModeRawValue) == OverlayMode.fallback
            else { return }
            if Self.hasNotchedDisplay {
                overlayModeRawValue = OverlayMode.notch.rawValue
            } else {
                overlayModeRawValue = OverlayMode.floatingWidget.rawValue
                UserDefaults.standard.set(
                    NotchWidgetLayout.miniBar.rawValue,
                    forKey: WidgetPreferences.layoutKey
                )
            }
        }
        .onDisappear {
            permissionTask?.cancel()
        }
    }

    private var isChecking: Bool {
        if case .checking = permissionStatus { return true }
        return false
    }

    @ViewBuilder
    private var permissionStatusView: some View {
        switch permissionStatus {
        case .unknown:
            EmptyView()
        case .checking:
            ProgressView()
                .controlSize(.small)
        case .granted:
            Label(String(localized: "Access granted"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .playerNotRunning:
            Label(String(localized: "The player is not running. Permission will be requested later"), systemImage: "info.circle")
                .foregroundStyle(.secondary)
                .font(.caption)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .font(.caption)
        }
    }

    private func checkPermission() {
        permissionTask?.cancel()
        permissionStatus = .checking
        permissionTask = Task { @MainActor in
            do {
                _ = try await PlaybackSourceRouter().fetchCurrentTrack()
                guard !Task.isCancelled else { return }
                permissionStatus = .granted
            } catch SpotifyPlaybackError.spotifyNotRunning {
                guard !Task.isCancelled else { return }
                permissionStatus = .playerNotRunning
            } catch {
                guard !Task.isCancelled else { return }
                permissionStatus = .failed(error.localizedDescription)
            }
        }
    }
}
