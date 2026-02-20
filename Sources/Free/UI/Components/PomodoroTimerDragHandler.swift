import SwiftUI

enum PomodoroTimerDragHandler {
    static func apply(
        location: CGPoint,
        center: CGPoint,
        maxMinutes: Double,
        durationMinutes: Binding<Double>
    ) {
        durationMinutes.wrappedValue = PomodoroTimerView.calculateDuration(
            location: location,
            center: center,
            maxMinutes: maxMinutes
        )
    }

    static func onChanged(
        center: CGPoint,
        maxMinutes: Double,
        durationMinutes: Binding<Double>
    ) -> (DragGesture.Value) -> Void {
        { value in
            apply(
                location: value.location,
                center: center,
                maxMinutes: maxMinutes,
                durationMinutes: durationMinutes
            )
        }
    }
}
