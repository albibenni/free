import AppKit

struct FocusColor {
    static let all: [NSColor] = [
        .systemBlue,
        .systemPurple,
        .systemOrange,
        .systemGreen,
        .systemRed,
        .systemPink,
        .systemIndigo,
        .systemTeal,
        .systemGray,
    ]

    static func nsColor(for index: Int) -> NSColor {
        let safeIndex = max(0, min(index, all.count - 1))
        return all[safeIndex]
    }
}
