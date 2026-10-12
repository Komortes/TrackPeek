import Foundation

/// Keeps player snapshots from moving the thumb during a drag. Keyboard and
/// accessibility edits commit immediately because they have no drag lifecycle.
struct VolumeControlState {
    private var draft: Double?
    private var isEditing = false

    func displayedValue(snapshot: Int?) -> Double {
        draft ?? Double(min(max(snapshot ?? 50, 0), 100))
    }

    mutating func change(to value: Double) -> Int? {
        guard value.isFinite else { return nil }
        let clamped = min(max(value, 0), 100)
        draft = clamped
        return isEditing ? nil : Int(clamped.rounded())
    }

    mutating func editingChanged(_ editing: Bool) -> Int? {
        isEditing = editing
        guard !editing, let draft else { return nil }
        self.draft = nil
        return Int(draft.rounded())
    }

    mutating func snapshotDidChange() {
        if !isEditing { draft = nil }
    }
}
