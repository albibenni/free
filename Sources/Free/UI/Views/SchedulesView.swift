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
    @EnvironmentObject var appState: AppState
    @State private var viewMode = 1  // 0 = List, 1 = Calendar
    @State private var editorContext: ScheduleEditorContext?

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
                    ForEach($appState.schedules) { $schedule in
                        ScheduleRow(
                            schedule: $schedule,
                            onDelete: {
                                if let index = appState.schedules.firstIndex(where: {
                                    $0.id == schedule.id
                                }) {
                                    appState.schedules.remove(at: index)
                                }
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editorContext = ScheduleEditorContext(schedule: schedule)
                        }
                    }
                    .onDelete { indexSet in
                        appState.schedules.remove(atOffsets: indexSet)
                    }
                }
                .listStyle(InsetListStyle())
            } else {
                WeeklyCalendarView(editorContext: $editorContext)
            }

            Divider()

            Button(action: {
                editorContext = ScheduleEditorContext()
            }) {
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
        .sheet(item: $editorContext) { context in
            AddScheduleView(
                isPresented: Binding(
                    get: { editorContext != nil },
                    set: { if !$0 { editorContext = nil } }
                ),
                initialDay: context.day,
                initialStartTime: context.startTime,
                initialEndTime: context.endTime,
                existingSchedule: context.schedule,
                editorContext: context
            )
        }
    }
}
