import AppKit
import Testing

@testable import FreeLogic

struct FocusColorTests {

    @Test("FocusColor selection logic")
    func colorSelection() {
        #expect(FocusColor.nsColor(for: 0) == .systemBlue)
        #expect(FocusColor.nsColor(for: 1) == .systemPurple)
        #expect(FocusColor.isRainbowAccentIndex(FocusColor.rainbowAccentIndex))
        #expect(FocusColor.isRainbowAccentColor(FocusColor.nsColor(for: FocusColor.rainbowAccentIndex)))
        #expect(FocusColor.accentOptionCount == FocusColor.all.count)

        let lastIndex = FocusColor.rainbowAccentIndex - 1
        #expect(FocusColor.nsColor(for: 100) == FocusColor.all[lastIndex])
        #expect(FocusColor.nsColor(for: -1) == .systemBlue)
    }
}
