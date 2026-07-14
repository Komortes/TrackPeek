import SwiftUI

/// Label content for the primary `MenuBarExtra`. Clicking anywhere on this
/// view still opens the existing popover — the optional prev/play/next
/// buttons live in separate `NSStatusItem`s managed by
/// `MenuBarControlsController`, not here.
struct MenuBarLabelView: View {
    let controller: MenuBarControlsController

    @AppStorage(MenuBarPreferences.controlsEnabledKey)
    private var controlsEnabled = MenuBarPreferences.controlsEnabledFallback
    @AppStorage(MenuBarPreferences.showsTitleKey)
    private var showsTitle = MenuBarPreferences.showsTitleFallback
    @AppStorage(MenuBarPreferences.showsEqualizerKey)
    private var showsEqualizer = MenuBarPreferences.showsEqualizerFallback
    @AppStorage(MenuBarPreferences.titleWidthKey)
    private var titleWidth = MenuBarPreferences.titleWidthFallback
    @AppStorage(MenuBarPreferences.spacingKey)
    private var spacing = MenuBarPreferences.spacingFallback

    var body: some View {
        Group {
            if
                controlsEnabled,
                let track = controller.model.track,
                controller.model.availability == .ready {
                HStack(spacing: MenuBarPreferences.clampedSpacing(spacing)) {
                    if showsEqualizer {
                        ArtworkEqualizerView(
                            audioMonitor: controller.audioMonitor,
                            isPlaying: track.isPlaying,
                            isVisible: true,
                            isColored: false,
                            palette: .fallback
                        )
                        .frame(width: 14, height: 12)
                    }

                    if showsTitle {
                        Text(track.title)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(
                                maxWidth: MenuBarPreferences.clampedTitleWidth(titleWidth),
                                alignment: .leading
                            )
                    }
                }
            } else {
                Image(systemName: "music.note")
            }
        }
        .accessibilityLabel("TrackPeek")
    }
}
