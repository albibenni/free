import AppKit

struct FocusColor {
    private static let rainbowMarker = NSColor(calibratedRed: 0.99, green: 0.11, blue: 0.79, alpha: 1)

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
        rainbowMarker,
    ]

    static let rainbowAccentIndex = all.count - 1
    static let accentOptionCount = all.count
    static let rainbowGradient: [NSColor] = [
        .systemRed,
        .systemOrange,
        .systemYellow,
        .systemGreen,
        .systemTeal,
        .systemBlue,
        .systemPurple,
        .systemPink,
    ]

    static func nsColor(for index: Int) -> NSColor {
        if isRainbowAccentIndex(index) {
            return rainbowMarker
        }
        let safeIndex = max(0, min(index, all.count - 2))
        return all[safeIndex]
    }

    static func isRainbowAccentIndex(_ index: Int) -> Bool {
        index == rainbowAccentIndex
    }

    static func isRainbowAccentColor(_ color: NSColor) -> Bool {
        guard
            let lhs = color.usingColorSpace(.deviceRGB),
            let rhs = rainbowMarker.usingColorSpace(.deviceRGB)
        else { return false }
        return abs(lhs.redComponent - rhs.redComponent) < 0.0001
            && abs(lhs.greenComponent - rhs.greenComponent) < 0.0001
            && abs(lhs.blueComponent - rhs.blueComponent) < 0.0001
            && abs(lhs.alphaComponent - rhs.alphaComponent) < 0.0001
    }
}
