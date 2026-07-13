import SwiftUI

struct TrackInfoView: View {
    let track: SpotifyTrack
    let showsAlbum: Bool
    let titleLineLimit: Int
    var isCentered = false
    var isProminent = false

    var body: some View {
        VStack(alignment: isCentered ? .center : .leading, spacing: 3) {
            Text(track.title)
                .font(.system(size: isProminent ? 17 : 15, weight: .semibold))
                .lineLimit(titleLineLimit)
                .truncationMode(.tail)
                .layoutPriority(1)
                .contentTransition(.opacity)
                .help(track.title)

            Text(track.artist)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(track.artist)

            if showsAlbum, let album = track.album {
                Text(album)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(album)
            }
        }
        .multilineTextAlignment(isCentered ? .center : .leading)
        .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
    }
}
