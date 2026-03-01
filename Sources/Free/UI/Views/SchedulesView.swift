import SwiftUI

struct ScheduleEditorContext: Identifiable {
    let id = UUID()
    var day: Int?
    var startTime: Date?
    var endTime: Date?
    var schedule: Schedule?
    var weekOffset: Int = 0
}

struct SchedulesView: View {
    @EnvironmentObject private var environmentAppState: AppState
    private let actionAppState: AppState?
    var appState: AppState { actionAppState ?? environmentAppState }
    @State private var viewMode = 1  // 0 = List, 1 = Calendar
    @State private var editorContext: ScheduleEditorContext?

    init(initialViewMode: Int = 1, initialEditorContext: ScheduleEditorContext? = nil, actionAppState: AppState? = nil) {
        self.actionAppState = actionAppState
        _viewMode = State(initialValue: initialViewMode)
        _editorContext = State(initialValue: initialEditorContext)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("View Mode", selection: $viewMode) {
                Image(systemName: "list.bullet").tag(0)
                Image(systemName: "calendar").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if viewMode == 0 {
                List {
                    ForEach($environmentAppState.schedules) { $schedule in
                        ScheduleRow(
                            schedule: $schedule,
                            accentColorIndex: appState.accentColorIndex,
                            onDelete: deleteScheduleAction(scheduleId: schedule.id)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture(perform: selectScheduleAction(schedule: schedule))
                    }
                    .onDelete(perform: removeSchedules(at:))
                }
                .listStyle(InsetListStyle())
            } else {
                WeeklyCalendarView(editorContext: $editorContext)
            }

            Divider()

            Button(action: openAddSchedule) {
                Text("Add Schedule")
            }
            .buttonStyle(
                AppPrimaryButtonStyle(
                    color: FocusColor.color(for: appState.accentColorIndex),
                    maxWidth: .infinity
                )
            )
            .padding()
            .frame(maxWidth: .infinity)
        }
        .sheet(item: $editorContext, content: makeAddScheduleSheet(context:))
    }

    func deleteScheduleAction(scheduleId: UUID) -> () -> Void {
        {
            guard let schedule = appState.schedules.first(where: { $0.id == scheduleId }) else { return }
            guard schedule.importedCalendarEventKey == nil else { return }
            appState.deleteSchedule(id: scheduleId, modifyAllDays: true, initialDay: nil)
        }
    }

    func selectScheduleAction(schedule: Schedule) -> () -> Void {
        {
            editorContext = ScheduleEditorContext(schedule: schedule)
        }
    }

    func removeSchedules(at indexSet: IndexSet) {
        let idsToDelete: [UUID] = indexSet.compactMap { offset in
            guard appState.schedules.indices.contains(offset) else { return nil }
            let schedule = appState.schedules[offset]
            guard schedule.importedCalendarEventKey == nil else { return nil }
            return schedule.id
        }
        for id in idsToDelete {
            appState.deleteSchedule(id: id, modifyAllDays: true, initialDay: nil)
        }
    }

    func openAddSchedule() {
        editorContext = ScheduleEditorContext()
    }

    func makeEditorPresentationBinding() -> Binding<Bool> {
        Binding(
            get: { editorContext != nil },
            set: { if !$0 { editorContext = nil } }
        )
    }

    func makeAddScheduleSheet(context: ScheduleEditorContext) -> some View {
        AddScheduleView(
            isPresented: makeEditorPresentationBinding(),
            initialDay: context.day,
            initialStartTime: context.startTime,
            initialEndTime: context.endTime,
            existingSchedule: context.schedule,
            editorContext: context
        )
    }

    var viewModeForTesting: Int { viewMode }
    var editorContextForTesting: ScheduleEditorContext? { editorContext }
}
