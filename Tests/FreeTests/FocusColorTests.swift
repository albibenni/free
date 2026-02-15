import Testing
import SwiftUI
@testable import FreeLogic

struct FocusColorTests {
    
    @Test("FocusColor selection logic")
    func colorSelection() {
        // Valid indices
        #expect(FocusColor.color(for: 0) == .blue)
        #expect(FocusColor.color(for: 1) == .purple)
        
        // Out of bounds (high)
        let lastIndex = FocusColor.all.count - 1
        #expect(FocusColor.color(for: 100) == FocusColor.all[lastIndex])
        
        // Out of bounds (low/negative)
        #expect(FocusColor.color(for: -1) == .blue)
    }

    @Test("Schedule extension themeColor")
    func scheduleThemeColor() {
        let schedule = Schedule(name: "Test", days: [], startTime: Date(), endTime: Date(), colorIndex: 2)
        #expect(schedule.themeColor == .orange)
    }
}
