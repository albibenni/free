import AppKit
import Foundation

@MainActor
enum ScheduleEditorRecurringUICoordinator {
    static func applyRecurringUI(
        repeatCheckbox: NSButton?,
        recurringDaysSection: NSView?,
        recurringDayButtons: [Int: ActionButton],
        days: Set<Int>,
        isRecurring: Bool,
        accentColor: NSColor
    ) {
        repeatCheckbox?.state = isRecurring ? .on : .off
        recurringDaysSection?.alphaValue = isRecurring ? 1 : 0.45

        for (day, button) in recurringDayButtons {
            let isSelected = days.contains(day)
            button.isEnabled = isRecurring
            button.layer?.backgroundColor = (
                isSelected
                    ? accentColor.withAlphaComponent(isRecurring ? 1 : 0.45)
                    : NSColor.secondaryLabelColor.withAlphaComponent(isRecurring ? 0.2 : 0.12)
            ).cgColor
            button.attributedTitle = NSAttributedString(
                string: ScheduleEditorSupport.daySymbol(at: day),
                attributes: [
                    .font: NSFont.systemFont(ofSize: 16, weight: .bold),
                    .foregroundColor: isSelected
                        ? NSColor.white.withAlphaComponent(isRecurring ? 1 : 0.75)
                        : NSColor.labelColor.withAlphaComponent(isRecurring ? 1 : 0.6),
                ]
            )
        }
    }
}
