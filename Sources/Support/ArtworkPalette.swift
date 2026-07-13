import AppKit
import Foundation

struct ArtworkColor: Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    var brightness: Double {
        max(red, green, blue)
    }

    var saturation: Double {
        guard brightness > 0 else { return 0 }
        return (brightness - min(red, green, blue)) / brightness
    }

    func distance(to other: ArtworkColor) -> Double {
        let redDistance = red - other.red
        let greenDistance = green - other.green
        let blueDistance = blue - other.blue
        return sqrt(
            redDistance * redDistance
                + greenDistance * greenDistance
                + blueDistance * blueDistance
        )
    }

    func mixed(with other: ArtworkColor, amount: Double) -> ArtworkColor {
        let amount = min(max(amount, 0), 1)
        return ArtworkColor(
            red: red + (other.red - red) * amount,
            green: green + (other.green - green) * amount,
            blue: blue + (other.blue - blue) * amount
        )
    }
}

struct ArtworkPalette: Equatable, Sendable {
    let primary: ArtworkColor
    let secondary: ArtworkColor
    let tertiary: ArtworkColor

    static let fallback = ArtworkPalette(
        primary: ArtworkColor(red: 0.35, green: 0.78, blue: 0.98),
        secondary: ArtworkColor(red: 0.68, green: 0.45, blue: 0.98),
        tertiary: ArtworkColor(red: 0.20, green: 0.92, blue: 0.72)
    )

    var colors: [ArtworkColor] {
        [primary, secondary, tertiary]
    }
}

enum ArtworkPaletteExtractor {
    static func palette(from samples: [ArtworkColor]) -> ArtworkPalette {
        guard !samples.isEmpty else { return .fallback }

        let candidates = samples
            .filter { $0.brightness > 0.07 && $0.brightness < 0.98 }
            .sorted { quality(of: $0) > quality(of: $1) }
        let source = candidates.isEmpty ? samples : candidates
        guard let primary = source.first else { return .fallback }

        var selected = [primary]
        while selected.count < 3 {
            guard let candidate = source
                .filter({ !selected.contains($0) })
                .max(by: {
                    selectionScore($0, against: selected)
                        < selectionScore($1, against: selected)
                }),
                selected.allSatisfy({ candidate.distance(to: $0) > 0.16 })
            else {
                break
            }
            selected.append(candidate)
        }

        let accents = ArtworkPalette.fallback.colors
        while selected.count < 3 {
            let accent = accents[selected.count]
            var variant = primary.mixed(with: accent, amount: 0.62)
            if selected.contains(variant) {
                variant = accent
            }
            selected.append(variant)
        }

        return ArtworkPalette(
            primary: selected[0],
            secondary: selected[1],
            tertiary: selected[2]
        )
    }

    private static func quality(of color: ArtworkColor) -> Double {
        color.saturation * 0.72 + color.brightness * 0.28
    }

    private static func selectionScore(
        _ color: ArtworkColor,
        against selected: [ArtworkColor]
    ) -> Double {
        let minimumDistance = selected.map { color.distance(to: $0) }.min() ?? 0
        return quality(of: color) + minimumDistance * 0.85
    }
}

actor ArtworkPaletteLoader {
    static let shared = ArtworkPaletteLoader()

    private let maximumCacheEntries = 48
    private var cache: [URL: ArtworkPalette] = [:]
    private var cacheOrder: [URL] = []

    func palette(for url: URL?) async -> ArtworkPalette {
        guard
            let url,
            let scheme = url.scheme?.lowercased(),
            scheme == "https" || scheme == "http"
        else {
            return .fallback
        }
        if let cached = cache[url] {
            cacheOrder.removeAll { $0 == url }
            cacheOrder.append(url)
            return cached
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 12
            request.cachePolicy = .returnCacheDataElseLoad
            let (data, response) = try await URLSession.shared.data(for: request)
            guard
                let response = response as? HTTPURLResponse,
                200 ... 299 ~= response.statusCode,
                data.count <= 8_000_000
            else {
                return .fallback
            }

            let palette = extractPalette(from: data)
            store(palette, for: url)
            return palette
        } catch {
            return .fallback
        }
    }

    private func store(_ palette: ArtworkPalette, for url: URL) {
        cache[url] = palette
        cacheOrder.removeAll { $0 == url }
        cacheOrder.append(url)

        while cacheOrder.count > maximumCacheEntries {
            cache.removeValue(forKey: cacheOrder.removeFirst())
        }
    }

    private func extractPalette(from data: Data) -> ArtworkPalette {
        guard let bitmap = NSBitmapImageRep(data: data) else { return .fallback }

        let columns = 10
        let rows = 10
        let width = max(bitmap.pixelsWide, 1)
        let height = max(bitmap.pixelsHigh, 1)
        var samples: [ArtworkColor] = []
        samples.reserveCapacity(columns * rows)

        for row in 0 ..< rows {
            for column in 0 ..< columns {
                let x = min((column * width + width / 2) / columns, width - 1)
                let y = min((row * height + height / 2) / rows, height - 1)
                guard
                    let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB)
                else {
                    continue
                }
                samples.append(
                    ArtworkColor(
                        red: color.redComponent,
                        green: color.greenComponent,
                        blue: color.blueComponent
                    )
                )
            }
        }

        return ArtworkPaletteExtractor.palette(from: samples)
    }
}
