import AppKit
import CoreGraphics

/// Стабильный идентификатор дисплея: UUID из Quartz переживает
/// перезагрузки и переподключения (в отличие от CGDirectDisplayID).
enum DisplayIdentity {
    static func persistentIdentifier(for screen: NSScreen) -> String {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard
            let number = screen.deviceDescription[key] as? NSNumber,
            let uuidRef = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)
        else {
            // Fallback: геометрия экрана — хуже UUID, но лучше одного
            // глобального ключа на все дисплеи.
            return "\(Int(screen.frame.width))x\(Int(screen.frame.height))"
        }
        let uuid = uuidRef.takeRetainedValue()
        return CFUUIDCreateString(nil, uuid) as String
    }
}


struct ConnectedDisplayChoice: Identifiable {
    let id: String
    let title: String

    @MainActor
    static func current() -> [ConnectedDisplayChoice] {
        let screens = NSScreen.screens
        return screens.enumerated().map { index, screen in
            let duplicateName = screens.filter { $0.localizedName == screen.localizedName }.count > 1
            let suffix = duplicateName ? " · \(index + 1)" : ""
            let resolution = "\(Int(screen.frame.width)) × \(Int(screen.frame.height))"
            return ConnectedDisplayChoice(
                id: DisplayIdentity.persistentIdentifier(for: screen),
                title: "\(screen.localizedName)\(suffix) — \(resolution)"
            )
        }
    }
}
