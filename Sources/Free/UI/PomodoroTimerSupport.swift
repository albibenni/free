import CoreGraphics
import Foundation

enum PomodoroTimerSupport {
    enum Constants {
        static let strokeWidth: CGFloat = 22
        static let knobSize: CGFloat = 16
        static let trackOpacity: Double = 0.15
    }

    static func calculateDuration(
        location: CGPoint,
        center: CGPoint,
        maxMinutes: Double
    ) -> Double {
        let vector = CGVector(dx: location.x - center.x, dy: location.y - center.y)
        var angleRadians = atan2(vector.dy, vector.dx)

        angleRadians += .pi / 2

        if angleRadians < 0 {
            angleRadians += 2 * .pi
        }

        let fraction = angleRadians / (2 * .pi)
        let newDuration = fraction * maxMinutes

        let step: Double = 5
        return max(step, min(maxMinutes, round(newDuration / step) * step))
    }

    static func apply(
        location: CGPoint,
        center: CGPoint,
        maxMinutes: Double,
        durationMinutes: inout Double
    ) {
        durationMinutes = calculateDuration(
            location: location,
            center: center,
            maxMinutes: maxMinutes
        )
    }

    static func onChanged(
        center: CGPoint,
        maxMinutes: Double,
        update: @escaping (Double) -> Void
    ) -> (CGPoint) -> Void {
        { location in
            update(
                calculateDuration(
                    location: location,
                    center: center,
                    maxMinutes: maxMinutes
                )
            )
        }
    }
}
