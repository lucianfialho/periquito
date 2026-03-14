import Foundation

@MainActor
@Observable
final class SoundSelector {
    var isPickerExpanded = false

    private static let rowHeight: CGFloat = 28
    private static let rowSpacing: CGFloat = 4
    private static let maxVisibleRows = 6

    var expandedHeight: CGFloat {
        let soundCount = NotificationSound.allCases.count
        let visibleCount = min(soundCount, Self.maxVisibleRows)
        return CGFloat(visibleCount) * Self.rowHeight + CGFloat(visibleCount - 1) * Self.rowSpacing
    }
}
