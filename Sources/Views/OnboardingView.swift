import AppKit
import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @AppStorage(MediaSourcePreference.storageKey)
    private var mediaSourceRawValue = MediaSourcePreference.fallback.rawValue

    @State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled
    @State private var permissionStatus: PermissionStatus = .unknown
    @State private var permissionTask: Task<Void, Never>?

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

                Text("Добро пожаловать в TrackPeek")
                    .font(.title2.weight(.semibold))

                Text("Плеер вокруг чёлки и в строке меню для Spotify и Apple Music.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Источник музыки", systemImage: "music.note.list")
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
                    Label("Доступ к плееру", systemImage: "lock.shield")
                        .font(.subheadline.weight(.semibold))

                    Text("TrackPeek управляет плеером через Apple Events — macOS спросит разрешение один раз.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Button("Проверить доступ", action: checkPermission)
                            .disabled(isChecking)

                        permissionStatusView
                    }
                }

                Toggle("Запускать при входе в систему", isOn: $launchAtLoginEnabled)
                    .onChange(of: launchAtLoginEnabled) { _, enabled in
                        LaunchAtLogin.setEnabled(enabled)
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))

            Button("Готово") {
                onFinish()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 380)
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
            Label("Доступ есть", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .playerNotRunning:
            Label("Плеер не запущен — запрос появится позже", systemImage: "info.circle")
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
