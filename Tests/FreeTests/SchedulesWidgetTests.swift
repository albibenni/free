import AppKit
import Foundation
import SwiftUI
import Testing
import ViewInspector

@testable import FreeLogic

@Suite(.serialized)
struct SchedulesWidgetTests {
    private func isolatedAppState(name: String) -> AppState {
        let suite = "SchedulesWidgetTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppState(defaults: defaults, isTesting: true)
    }

    @MainActor
    private func host<V: View>(_ view: V, size: CGSize = CGSize(width: 560, height: 560))
        -> NSHostingView<V>
    {
        let hosted = NSHostingView(rootView: view)
        hosted.frame = NSRect(origin: .zero, size: size)
        hosted.layoutSubtreeIfNeeded()
        hosted.displayIfNeeded()
        return hosted
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

    @Test("SchedulesWidget collapsed header shows today badge only when enabled schedules exist")
    @MainActor
    func schedulesWidgetCollapsedBadge() throws {
        let appState = isolatedAppState(name: "collapsedBadge")
        appState.schedules = [schedule(name: "Active", enabled: true, startOffsetMinutes: -60, endOffsetMinutes: 60)]

        var showSchedules = false
        let binding = Binding(get: { showSchedules }, set: { showSchedules = $0 })

        let sutWithBadge = SchedulesWidget(showSchedules: binding)
            .environmentObject(appState)
        let hosted = host(sutWithBadge)
        #expect(hosted.fittingSize.height >= 0)
        #expect((try? sutWithBadge.inspect().find(text: "1 today")) != nil)
        try sutWithBadge.inspect().findAll(ViewType.Button.self).first?.tap()

        appState.schedules = [schedule(name: "Disabled", enabled: false, startOffsetMinutes: -60, endOffsetMinutes: 60)]
        let sutNoBadge = SchedulesWidget(showSchedules: binding)
            .environmentObject(appState)
        #expect((try? sutNoBadge.inspect().find(text: "1 today")) == nil)
    }

    @Test("SchedulesWidget expanded empty state and open-calendar action")
    @MainActor
    func schedulesWidgetExpandedEmptyStateAndOpenAction() throws {
        let appState = isolatedAppState(name: "expandedEmpty")
        appState.schedules = []

        var showSchedules = false
        let binding = Binding(get: { showSchedules }, set: { showSchedules = $0 })
        let sut = SchedulesWidget(showSchedules: binding, initialIsExpanded: true)
            .environmentObject(appState)
        #expect((try? sut.inspect().find(text: "No schedules planned for today.")) != nil)
        #expect((try? sut.inspect().find(text: "Open Full Calendar")) != nil)

        try sut.inspect().findAll(ViewType.Button.self).last?.tap()
        #expect(showSchedules == true)
    }

    @Test("SchedulesWidget expanded list covers disabled and active schedule row branches")
    @MainActor
    func schedulesWidgetExpandedRows() throws {
        let appState = isolatedAppState(name: "expandedRows")
        let active = schedule(name: "Deep Work", enabled: true, startOffsetMinutes: -30, endOffsetMinutes: 30)
        let disabled = schedule(name: "Muted", enabled: false, startOffsetMinutes: 120, endOffsetMinutes: 180, type: .unfocus)
        appState.schedules = [active, disabled]

        var showSchedules = false
        let binding = Binding(get: { showSchedules }, set: { showSchedules = $0 })
        let sut = SchedulesWidget(showSchedules: binding, initialIsExpanded: true)
            .environmentObject(appState)

        #expect((try? sut.inspect().find(text: "Deep Work")) != nil)
        #expect((try? sut.inspect().find(text: "Muted")) != nil)
        #expect((try? sut.inspect().find(text: "Focus")) != nil)
        #expect((try? sut.inspect().find(text: "Break")) != nil)
        #expect((try? sut.inspect().find(text: "Disabled")) != nil)
    }
}
