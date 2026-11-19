// Creates the standard and Retina representations for the Finder window.
import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let catalog = URL(fileURLWithPath: CommandLine.arguments[2])
let language = CommandLine.arguments[3]
let strings = try JSONSerialization.jsonObject(with: Data(contentsOf: catalog)) as? [String: Any]
let entries = strings?["strings"] as? [String: Any]
let instruction = "Drag TrackPeek to Applications."
let entry = entries?[instruction] as? [String: Any]
let translations = entry?["localizations"] as? [String: [String: [String: String]]]
guard let subtitle = translations?[language]?["stringUnit"]?["value"] else {
    throw CocoaError(.fileReadCorruptFile)
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
}

func drawBackground(scale: Int) throws {
    let width = 600, height = 340
    guard let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width * scale,
        pixelsHigh: height * scale, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: image) else { throw CocoaError(.coderInvalidValue) }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

    rgb(242, 243, 248).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
    NSGradient(starting: rgb(32, 28, 62), ending: rgb(22, 40, 51))?.draw(
        in: NSRect(x: 0, y: 222, width: width, height: 118), angle: 0)

    ("TrackPeek" as NSString).draw(at: NSPoint(x: 32, y: 278), withAttributes: [
        .font: NSFont.systemFont(ofSize: 29, weight: .semibold), .foregroundColor: NSColor.white
    ])
    (subtitle as NSString).draw(at: NSPoint(x: 33, y: 247), withAttributes: [
        .font: NSFont.systemFont(ofSize: 16), .foregroundColor: rgb(218, 224, 239)
    ])

    // The five bands echo the application's own equalizer icon.
    let bands = [(12, rgb(104, 172, 249)), (22, rgb(147, 136, 247)), (30, rgb(196, 147, 255)),
                 (19, rgb(153, 217, 255)), (25, rgb(102, 232, 199))]
    for (index, band) in bands.enumerated() {
        band.1.setFill()
        let bar = NSRect(x: 512 + CGFloat(index) * 10, y: 279 - CGFloat(band.0) / 2, width: 5, height: CGFloat(band.0))
        NSBezierPath(roundedRect: bar, xRadius: 2.5, yRadius: 2.5).fill()
    }

    // Finder places the actual app and folder icons on either side.
    let arrow = NSBezierPath()
    let centerY = CGFloat(height - 211)
    arrow.move(to: NSPoint(x: 272, y: centerY))
    arrow.line(to: NSPoint(x: 327, y: centerY))
    arrow.move(to: NSPoint(x: 316, y: centerY + 10))
    arrow.line(to: NSPoint(x: 327, y: centerY))
    arrow.line(to: NSPoint(x: 316, y: centerY - 10))
    arrow.lineWidth = 3
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    rgb(107, 97, 158).setStroke()
    arrow.stroke()
    NSGraphicsContext.restoreGraphicsState()

    image.size = NSSize(width: width, height: height)
    guard let data = image.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
    let name = scale == 1 ? "background.png" : "background@2x.png"
    try data.write(to: directory.appendingPathComponent(name))
}

try drawBackground(scale: 1)
try drawBackground(scale: 2)
