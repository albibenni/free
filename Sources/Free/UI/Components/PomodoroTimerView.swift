import SwiftUI

struct PomodoroConstants {
    static let strokeWidth: CGFloat = 22
    static let knobSize: CGFloat = 16
    static let trackOpacity: Double = 0.15
}

struct ClockCenterContent: View {
    let iconName: String
    let color: Color
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 40))
                .foregroundColor(color.opacity(0.9))

            Text(text)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
        }
    }
}

struct PomodoroTimerView: View {
    @Binding var durationMinutes: Double
    let maxMinutes: Double
    let iconName: String
    let title: String
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = (size - PomodoroConstants.strokeWidth) / 2

            ZStack {
                // Background Circle (Track)
                Circle()
                    .stroke(Color.secondary.opacity(PomodoroConstants.trackOpacity), lineWidth: PomodoroConstants.strokeWidth)
                    .frame(width: radius * 2, height: radius * 2)

                // Progress Arc
                Circle()
                    .trim(from: 0, to: CGFloat(durationMinutes / maxMinutes))
                    .stroke(color, style: StrokeStyle(lineWidth: PomodoroConstants.strokeWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: radius * 2, height: radius * 2)

                // Draggable Knob
                Circle()
                    .fill(color)
                    .frame(width: PomodoroConstants.knobSize, height: PomodoroConstants.knobSize)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .position(
                        position(for: durationMinutes, radius: radius, center: center)
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateDuration(location: value.location, center: center)
                            }
                    )

                ClockCenterContent(iconName: iconName, color: color, text: "\(Int(durationMinutes))m")
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func position(for duration: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let fraction = duration / maxMinutes
        let angle = Angle(degrees: fraction * 360 - 90)
        let x = center.x + radius * CGFloat(cos(angle.radians))
        let y = center.y + radius * CGFloat(sin(angle.radians))
        return CGPoint(x: x, y: y)
    }

    private func updateDuration(location: CGPoint, center: CGPoint) {
        durationMinutes = PomodoroTimerView.calculateDuration(
            location: location,
            center: center,
            maxMinutes: maxMinutes
        )
    }

    static func calculateDuration(location: CGPoint, center: CGPoint, maxMinutes: Double) -> Double {
        let vector = CGVector(dx: location.x - center.x, dy: location.y - center.y)
        var angleRadians = atan2(vector.dy, vector.dx)

        // Adjust coordinate system so -90 degrees (top) is 0
        angleRadians += .pi / 2

        if angleRadians < 0 { angleRadians += 2 * .pi }

        let fraction = angleRadians / (2 * .pi)
        let newDuration = fraction * maxMinutes

        // Snap to nearest 5 minutes
        let step: Double = 5
        return max(step, min(maxMinutes, round(newDuration / step) * step))
    }
}

struct PomodoroProgressView: View {
    let progress: Double
    let iconName: String
    let title: String
    let color: Color
    let timeString: String

    var body: some View {
        ZStack {
            // Background Circle (Track)
            Circle()
                .stroke(Color.secondary.opacity(PomodoroConstants.trackOpacity), lineWidth: PomodoroConstants.strokeWidth)

            // Progress Arc
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(color, style: StrokeStyle(lineWidth: PomodoroConstants.strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            ClockCenterContent(iconName: iconName, color: color, text: timeString)
        }
    }
}
