import AppKit
import SwiftUI
import Testing

@testable import FreeLogic

@Suite(.serialized)
struct PomodoroTimerViewTests {
    private final class DurationBox {
        var value: Double
        init(_ value: Double) { self.value = value }
    }

    @MainActor
    private func host<V: View>(_ view: V, size: CGSize = CGSize(width: 240, height: 240))
        -> NSHostingView<V>
    {
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(origin: .zero, size: size)
        hosted.layoutSubtreeIfNeeded()
        hosted.displayIfNeeded()
        return hosted
    }

    private func makeDragValue(
        location: CGPoint, startLocation: CGPoint = .zero, time: Date = Date()
    ) -> DragGesture.Value {
        let size = MemoryLayout<DragGesture.Value>.size
        let alignment = MemoryLayout<DragGesture.Value>.alignment
        let raw = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: alignment)
        raw.initializeMemory(as: UInt8.self, repeating: 0, count: size)
        defer { raw.deallocate() }

        var value = raw.load(as: DragGesture.Value.self)
        value.time = time
        value.location = location
        value.startLocation = startLocation
        return value
    }

    @Test("ClockCenterContent can build and render in hosting view")
    @MainActor
    func clockCenterContentRender() {
        let view = ClockCenterContent(iconName: "timer", color: .green, text: "25m")
            .frame(width: 120, height: 120)
        let hosted = host(view, size: CGSize(width: 120, height: 120))
        #expect(hosted.fittingSize.width >= 0)
    }

    @Test("PomodoroProgressView can build and render in hosting view")
    @MainActor
    func progressViewRender() {
        let view = PomodoroProgressView(
            progress: 0.5,
            iconName: "flame.fill",
            title: "Focus",
            color: .red,
            timeString: "12:30"
        )
        .frame(width: 180, height: 180)
        let hosted = host(view, size: CGSize(width: 180, height: 180))
        #expect(hosted.fittingSize.height >= 0)
    }

    @Test("PomodoroTimerView can build and render in hosting view")
    @MainActor
    func timerViewRender() {
        let duration = DurationBox(25)
        let binding = Binding<Double>(
            get: { duration.value },
            set: { duration.value = $0 }
        )
        let view = PomodoroTimerView(
            durationMinutes: binding,
            maxMinutes: 60,
            iconName: "flame.fill",
            title: "Focus",
            color: .orange
        )
        .frame(width: 220, height: 220)

        let hosted = host(view, size: CGSize(width: 220, height: 220))
        #expect(hosted.fittingSize.width >= 0)
        #expect(duration.value == 25)
    }

    @Test("Pomodoro duration normalizes negative angle and clamps bounds")
    func durationNegativeAngleAndClamp() {
        let center = CGPoint(x: 100, y: 100)
        let maxMins: Double = 60

        let topLeft = CGPoint(x: 50, y: 50)
        #expect(
            PomodoroTimerView.calculateDuration(
                location: topLeft, center: center, maxMinutes: maxMins) == 55)

        let top = CGPoint(x: 100, y: 0)
        #expect(
            PomodoroTimerView.calculateDuration(location: top, center: center, maxMinutes: maxMins)
                >= 5)

        let nearWrap = CGPoint(x: 99.9, y: 0)
        let wrapped = PomodoroTimerView.calculateDuration(
            location: nearWrap, center: center, maxMinutes: maxMins)
        #expect(wrapped <= 60)
    }

    @Test("Pomodoro drag handler applies duration into binding")
    func dragHandlerApply() {
        let duration = DurationBox(10)
        let binding = Binding<Double>(
            get: { duration.value },
            set: { duration.value = $0 }
        )

        PomodoroTimerDragHandler.apply(
            location: CGPoint(x: 150, y: 100),
            center: CGPoint(x: 100, y: 100),
            maxMinutes: 60,
            durationMinutes: binding
        )

        #expect(duration.value == 15)
    }

    @Test("Pomodoro drag handler onChanged closure can be created")
    func dragHandlerOnChangedCreation() {
        let duration = DurationBox(25)
        let binding = Binding<Double>(
            get: { duration.value },
            set: { duration.value = $0 }
        )

        let handler = PomodoroTimerDragHandler.onChanged(
            center: CGPoint(x: 100, y: 100),
            maxMinutes: 60,
            durationMinutes: binding
        )

        _ = handler
        #expect(duration.value == 25)
    }

    @Test("Pomodoro drag handler onChanged closure updates duration from drag value")
    func dragHandlerOnChangedInvocation() {
        let duration = DurationBox(25)
        let binding = Binding<Double>(
            get: { duration.value },
            set: { duration.value = $0 }
        )

        let handler = PomodoroTimerDragHandler.onChanged(
            center: CGPoint(x: 100, y: 100),
            maxMinutes: 60,
            durationMinutes: binding
        )

        let dragValue = makeDragValue(
            location: CGPoint(x: 150, y: 100), startLocation: CGPoint(x: 100, y: 100))
        handler(dragValue)

        #expect(duration.value == 15)
    }
}
