import SwiftUI

struct PomodoroTimerView: View {
    @Binding var durationMinutes: Double
    let maxMinutes: Double = 120
    let color: Color
    
    private let knobSize: CGFloat = 20
    private let strokeWidth: CGFloat = 15
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = (size - strokeWidth) / 2
            
            ZStack {
                // Background Circle (Track)
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: strokeWidth)
                    .frame(width: radius * 2, height: radius * 2)
                
                // Progress Arc
                Circle()
                    .trim(from: 0, to: CGFloat(durationMinutes / maxMinutes))
                    .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: radius * 2, height: radius * 2)
                
                // Draggable Knob
                Circle()
                    .fill(color)
                    .frame(width: knobSize, height: knobSize)
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
                
                // Center Content (Tree & Time)
                VStack(spacing: 4) {
                    Image(systemName: "tree.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color.green.opacity(0.8))
                    
                    Text("\(Int(durationMinutes))m")
                        .font(.title2.bold())
                        .monospacedDigit()
                }
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
        let vector = CGVector(dx: location.x - center.x, dy: location.y - center.y)
        var angleRadians = atan2(vector.dy, vector.dx)
        
        // Adjust coordinate system so -90 degrees (top) is 0
        angleRadians += .pi / 2
        
        if angleRadians < 0 {
            angleRadians += 2 * .pi
        }
        
        let fraction = angleRadians / (2 * .pi)
        let newDuration = fraction * maxMinutes
        
        // Snap to nearest 5 minutes for easier selection, or 1 minute if fine-grained
        // Let's snap to integers
        let snappedDuration = max(1, min(maxMinutes, round(newDuration)))
        
        durationMinutes = snappedDuration
    }
}
