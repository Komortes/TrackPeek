import AppKit
import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @AppStorage(MediaSourcePreference.storageKey)
    private var mediaSource = MediaSourcePreference.fallback
    @AppStorage(OverlayMode.storageKey)
    private var overlayMode = OverlayMode.fallback
    @AppStorage(NotchContentLayout.storageKey)
    private var notchLayout = NotchContentLayout.fallback
    @AppStorage(WidgetPreferences.layoutKey)
    private var widgetLayout = NotchWidgetLayout.fallback

    @AppStorage(WidgetPreferences.positionKey)
    private var widgetPosition = NotchWidgetPosition.fallback
    @AppStorage(WidgetPreferences.edgeOnRightKey)
    private var edgeOnRight = true
    @AppStorage(NotchPreferences.hoverEnabledKey)
    private var hoverEnabled = NotchPreferences.hoverEnabledFallback
    @AppStorage(NotchPreferences.clickEnabledKey)
    private var clickEnabled = NotchPreferences.clickEnabledFallback

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 54, height: 54)
                    .accessibilityHidden(true)
                SettingsSectionHeader(title: String(localized: "Welcome to TrackPeek"),
                    subtitle: String(localized: "A notch and menu bar player for Spotify and Apple Music."),
                    titleFont: .title2.weight(.semibold))
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SettingsSection(title: String(localized: "Music Source")) {
                        Picker(String(localized: "Music Source"), selection: $mediaSource) {
                            ForEach(MediaSourcePreference.allCases) { source in
                                Text(source.title).tag(source)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    SettingsSection(title: String(localized: "Where to Show the Player")) {
                        Picker(String(localized: "Where to Show the Player"), selection: $overlayMode) {
                            ForEach(OverlayMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        surfaceExample
                    }

                    Divider()
                    OnboardingAccessView(source: mediaSource)
                    LaunchAtLoginToggle()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
            }
            .scrollBounceBehavior(.basedOnSize)

            Divider()
            HStack(spacing: 12) {
                Button(String(localized: "More Settings"), action: showSettings)
                Spacer()
                Button(String(localized: "Done"), action: onFinish)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .frame(width: 504, height: 566)
    }

    private var surfaceExample: some View {
        HStack(spacing: 16) {
            desktopExample
                .padding(.vertical, 10)
                .padding(.leading, 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Preview"))
                    .font(.caption.weight(.semibold))
                Text(surfaceHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .padding(.trailing, 14)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    private var desktopExample: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [.indigo.opacity(0.45), .teal.opacity(0.28)],
                startPoint: .topLeading, endPoint: .bottomTrailing)

            HStack(spacing: 5) {
                Spacer()
                Image(systemName: "music.note")
                    .fontWeight(.bold)
                    .padding(.horizontal, 4)
                    .background(overlayMode == .off ? Color.accentColor : .clear, in: Capsule())
                    .foregroundStyle(overlayMode == .off ? Color.white : .primary)
                Image(systemName: "wifi")
                Image(systemName: "battery.100percent")
            }
            .font(.system(size: 8))
            .padding(.horizontal, 6)
            .frame(height: 14)
            .background(.regularMaterial)

            switch overlayMode {
            case .notch:
                SettingsPlayerPreview(surface: .notch(notchLayout), alignment: .top)
            case .floatingWidget:
                SettingsPlayerPreview(surface: .widget(widgetLayout), alignment: widgetAlignment)
                    .padding(.top, 17)
                    .padding([.horizontal, .bottom], 4)
            case .off:
                EmptyView()
            }
        }
        .frame(width: 194, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var widgetAlignment: Alignment {
        if widgetLayout == .edge { return edgeOnRight ? .trailing : .leading }
        switch widgetPosition {
        case .topLeading: return .topLeading
        case .topCenter: return .top
        case .topTrailing: return .topTrailing
        case .bottomLeading: return .bottomLeading
        case .bottomCenter: return .bottom
        case .bottomTrailing: return .bottomTrailing
        }
    }

    private var surfaceHint: String {
        switch overlayMode {
        case .notch where hoverEnabled && clickEnabled:
            String(localized: "Hover to peek, or click the closed notch to keep the player open.")
        case .notch where hoverEnabled:
            String(localized: "Hover to expand the player")
        case .notch where clickEnabled:
            String(localized: "Click to expand the player")
        case .floatingWidget:
            widgetLayout.summary
        default:
            String(localized: "Click TrackPeek in the menu bar to open the player.")
        }
    }

    private func showSettings() {
        let tab: SettingsTab = switch overlayMode {
        case .notch: .notch
        case .floatingWidget: .widget
        case .off: .general
        }
        UserDefaults.standard.set(tab.rawValue, forKey: SettingsTab.selectionStorageKey)
        SettingsWindowPresentation.present(openSettings: openSettings.callAsFunction)
        onFinish()
    }
}
