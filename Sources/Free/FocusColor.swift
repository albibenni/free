import SwiftUI

struct FocusColor {
    static let all: [Color] = [
        .blue, .purple, .orange, .green, .red, .pink, .indigo, .teal, .gray
    ]
    
    static func color(for index: Int) -> Color {
        let safeIndex = max(0, min(index, all.count - 1))
        return all[safeIndex]
    }
}

extension Schedule {
    var themeColor: Color {
        FocusColor.color(for: colorIndex)
    }
}
