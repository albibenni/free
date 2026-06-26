import AppKit
import Foundation
import Testing

@testable import FreeLogic

@Suite(.serialized)
@MainActor
struct SchedulesWidgetTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "SchedulesWidgetTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @MainActor
    private func host(_ view: NSView, size: CGSize = CGSize(width: 560, height: 560)) -> NSView {
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        return view
    }

    private func visibleText(in view: NSView) -> [String] {
        guard !view.isHidden, view.alphaValue > 0.001 else { return [] }

        var values: [String] = []
        if let label = view as? NSTextField, !label.stringValue.isEmpty {
            values.append(label.stringValue)
        }
        if let button = view as? NSButton, !button.title.isEmpty {
            values.append(button.title)
        }

        for subview in view.subviews {
            values.append(contentsOf: visibleText(in: subview))
        }
        return values
    }

    private func buttons(in view: NSView) -> [NSButton] {
        var all: [NSButton] = []
        if let button = view as? NSButton {
            all.append(button)
        }
        for subview in view.subviews {
            all.append(contentsOf: buttons(in: subview))
        }
        return all
    }

    private func schedule(
        name: String,
        enabled: Bool,
        startOffsetMinutes: Int,
        endOffsetMinutes: Int,
        type: ScheduleType = .focus
    ) -> Schedule {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .minute, value: startOffsetMinutes, to: now) ?? now
        let end = calendar.date(byAdding: .minute, value: endOffsetMinutes, to: now) ?? now
        let weekday = calendar.component(.weekday, from: now)
        return Schedule(
            name: name,
            days: [weekday],
            date: nil,
            startTime: start,
            endTime: end,
            isEnabled: enabled,
            colorIndex: 2,
            type: type
        )
    }

    @Test("FocusSchedulesWidget renders empty state and opens the calendar sheet")
    @MainActor
    func schedulesWidgetEmptyStateAndOpenAction() async throws {
        let appState = isolatedAppState(name: "emptyState")
        appState.schedules = []

        let shellState = FreeShellState()
        let hosted = host(FocusSchedulesWidgetView(appState: appState, shellState: shellState))
        let texts = visibleText(in: hosted)

        #expect(texts.contains("Focus Schedules"))
        #expect(texts.contains("No schedules planned for today."))
        #expect(texts.contains("Open Full Calendar"))

        let openButton = buttons(in: hosted).first { $0.title == "Open Full Calendar" }
        #expect(openButton != nil)
        openButton?.performClick(nil)
        #expect(shellState.showSchedules)
    }

    @Test("FocusSchedulesWidget renders enabled and disabled schedule rows")
    @MainActor
    func schedulesWidgetRowsRender() async throws {
        let appState = isolatedAppState(name: "rowsRender")
        let active = schedule(name: "Deep Work", enabled: true, startOffsetMinutes: -30, endOffsetMinutes: 30)
        let inactiveEnabled = schedule(
            name: "Later",
            enabled: true,
            startOffsetMinutes: 180,
            endOffsetMinutes: 240,
            type: .focus
        )
        let disabled = schedule(
            name: "Muted",
            enabled: false,
            startOffsetMinutes: 120,
            endOffsetMinutes: 180,
            type: .unfocus
        )
        appState.schedules = [active, inactiveEnabled, disabled]

        let hosted = host(FocusSchedulesWidgetView(appState: appState, shellState: FreeShellState()))
        let texts = visibleText(in: hosted)

        #expect(texts.contains("Deep Work"))
        #expect(texts.contains("Later"))
        #expect(texts.contains("Muted"))
        #expect(texts.contains("Focus"))
        #expect(texts.contains("Break"))
        #expect(texts.contains("Disabled"))
        #expect(texts.contains("No schedules planned for today.") == false)
    }
}
