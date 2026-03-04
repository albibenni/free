import AppKit
import Testing

@testable import FreeLogic

struct FocusColorTests {

    @Test("FocusColor selection logic")
    func colorSelection() {
        #expect(FocusColor.nsColor(for: 0) == .systemBlue)
        #expect(FocusColor.nsColor(for: 1) == .systemPurple)

        let lastIndex = FocusColor.all.count - 1
        #expect(FocusColor.nsColor(for: 100) == FocusColor.all[lastIndex])
        #expect(FocusColor.nsColor(for: -1) == .systemBlue)
    }
}
