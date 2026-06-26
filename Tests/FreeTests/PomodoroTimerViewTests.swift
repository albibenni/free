import CoreGraphics
import Testing

@testable import FreeLogic

@Suite(.serialized)
@MainActor
struct PomodoroTimerViewTests {
    @Test("Pomodoro timer support exposes stable drawing constants")
    func timerConstants() async throws {
        #expect(PomodoroTimerSupport.Constants.strokeWidth == 22)
        #expect(PomodoroTimerSupport.Constants.knobSize == 16)
        #expect(PomodoroTimerSupport.Constants.trackOpacity == 0.15)
    }

    @Test("Pomodoro duration normalizes negative angle and clamps bounds")
    func durationNegativeAngleAndClamp() async throws {
        let center = CGPoint(x: 100, y: 100)
        let maxMins: Double = 60

        let topLeft = CGPoint(x: 50, y: 50)
        #expect(
            PomodoroTimerSupport.calculateDuration(
                location: topLeft,
                center: center,
                maxMinutes: maxMins
            ) == 55
        )

        let top = CGPoint(x: 100, y: 0)
        #expect(
            PomodoroTimerSupport.calculateDuration(
                location: top,
                center: center,
                maxMinutes: maxMins
            ) >= 5
        )

        let nearWrap = CGPoint(x: 99.9, y: 0)
        let wrapped = PomodoroTimerSupport.calculateDuration(
            location: nearWrap,
            center: center,
            maxMinutes: maxMins
        )
        #expect(wrapped <= 60)
    }

    @Test("Pomodoro timer support applies duration into an inout value")
    func dragHandlerApply() async throws {
        var duration = 10.0

        PomodoroTimerSupport.apply(
            location: CGPoint(x: 150, y: 100),
            center: CGPoint(x: 100, y: 100),
            maxMinutes: 60,
            durationMinutes: &duration
        )

        #expect(duration == 15)
    }

    @Test("Pomodoro timer support change handler can be created without updating state")
    func dragHandlerOnChangedCreation() async throws {
        var duration = 25.0

        let handler = PomodoroTimerSupport.onChanged(
            center: CGPoint(x: 100, y: 100),
            maxMinutes: 60
        ) { duration = $0 }

        _ = handler
        #expect(duration == 25)
    }

    @Test("Pomodoro timer support change handler updates duration from a point")
    func dragHandlerOnChangedInvocation() async throws {
        var duration = 25.0

        let handler = PomodoroTimerSupport.onChanged(
            center: CGPoint(x: 100, y: 100),
            maxMinutes: 60
        ) { duration = $0 }

        handler(CGPoint(x: 150, y: 100))

        #expect(duration == 15)
    }
}
