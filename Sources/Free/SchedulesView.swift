import SwiftUI

struct SchedulesView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddSchedule = false
    @State private var viewMode = 1 // 0 = List, 1 = Calendar

    // For passing data from Calendar click
    @State private var selectedDay: Int?
    @State private var selectedTime: Date?
    @State private var selectedEndTime: Date?
    @State private var selectedSchedule: Schedule?

    var body: some View {
        VStack(spacing: 0) {
            Picker("View Mode", selection: $viewMode) {
                Image(systemName: "list.bullet").tag(0)
                Image(systemName: "calendar").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if viewMode == 0 {
                // List View
                List {
                    ForEach($appState.schedules) { $schedule in
                        ScheduleRow(schedule: $schedule, onDelete: {
                            if let index = appState.schedules.firstIndex(where: { $0.id == schedule.id }) {
                                appState.schedules.remove(at: index)
                            }
                        })
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSchedule = schedule
                            showingAddSchedule = true
                        }
                    }
                    .onDelete { indexSet in
                        appState.schedules.remove(atOffsets: indexSet)
                    }
                }
                .listStyle(InsetListStyle())
            } else {
                // Calendar View
                WeeklyCalendarView(
                    showingAddSchedule: $showingAddSchedule,
                    selectedDay: $selectedDay,
                    selectedTime: $selectedTime,
                    selectedEndTime: $selectedEndTime,
                    selectedSchedule: $selectedSchedule
                )
            }

            Divider()

            Button(action: {
                // Reset defaults for manual add
                selectedDay = nil
                selectedTime = nil
                selectedEndTime = nil
                selectedSchedule = nil
                showingAddSchedule = true
            }) {
                Text("Add Schedule")
                    .font(.headline)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .tint(FocusColor.color(for: appState.accentColorIndex))
            .padding()
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showingAddSchedule) {
            AddScheduleView(
                isPresented: $showingAddSchedule,
                initialDay: selectedDay,
                initialStartTime: selectedTime,
                initialEndTime: selectedEndTime,
                existingSchedule: selectedSchedule
            )
            .id("\(selectedSchedule?.id.uuidString ?? "new")-\(selectedDay ?? -1)-\(selectedTime?.description ?? "")")
        }
    }
}

struct ScheduleRow: View {
    @Binding var schedule: Schedule
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(schedule.themeColor)
                .frame(width: 4, height: 35)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: schedule.type == .focus ? "target" : "cup.and.saucer.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(schedule.name)
                        .font(.headline)
                }
                Text(timeRangeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(daysString)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            Spacer()

            HStack(spacing: 12) {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.body)
                }
                .buttonStyle(.plain)

                Toggle("", isOn: $schedule.isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }
            .fixedSize()
        }
        .padding(.vertical, 4)
    }

    private var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: schedule.startTime)) - \(formatter.string(from: schedule.endTime))"
    }

    private var daysString: String {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return schedule.days.sorted().map { dayNames[$0 - 1] }.joined(separator: ", ")
    }
}

struct AddScheduleView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool

    // Optional initializers
    var initialDay: Int?
    var initialStartTime: Date?
    var initialEndTime: Date?
    var existingSchedule: Schedule?

    @State private var name = ""
    @State private var days: Set<Int> = [] // Start empty, let onAppear fill it
    @State private var startTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var endTime = Calendar.current.date(from: DateComponents(hour: 17, minute: 0)) ?? Date()
    @State private var selectedColorIndex: Int = 0
    @State private var sessionType: ScheduleType = .focus

    // Logic for splitting schedule
    @State private var modifyAllDays = true

    var dayOrder: [Int] {
        if appState.weekStartsOnMonday {
            return [2, 3, 4, 5, 6, 7, 1] // Mon -> Sun
        } else {
            return [1, 2, 3, 4, 5, 6, 7] // Sun -> Sat
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Text(existingSchedule == nil ? "New Schedule" : "Edit Schedule")
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(25)

            Divider()

            VStack(alignment: .leading, spacing: 20) {
                // Session Type
                VStack(alignment: .leading, spacing: 8) {
                    Text("SESSION TYPE")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    Picker("", selection: $sessionType) {
                        ForEach(ScheduleType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type == .focus ? "target" : "cup.and.saucer.fill")
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Edit Scope (if applicable)
                if existingSchedule != nil && initialDay != nil && (existingSchedule?.days.count ?? 0) > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EDIT SCOPE")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)

                        Picker("", selection: $modifyAllDays) {
                            Text("All Days").tag(true)
                            Text("Only \(dayName(for: initialDay!))").tag(false)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                // Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("SCHEDULE NAME")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    TextField(sessionType == .focus ? "Focus Session" : "Break Session", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                }

                // Color Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("THEME COLOR")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        ForEach(0..<FocusColor.all.count, id: \.self) { index in
                            Circle()
                                .fill(FocusColor.all[index])
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColorIndex == index ? 2 : 0)
                                        .padding(-4)
                                )
                                .contentShape(Circle())
                                .onTapGesture {
                                    selectedColorIndex = index
                                }
                        }
                    }
                }

                // Times
                HStack(spacing: 40) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("START TIME")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.field)
                            .scaleEffect(1.1)
                            .frame(width: 90, height: 35)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("END TIME")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.field)
                            .scaleEffect(1.1)
                            .frame(width: 90, height: 35)
                    }
                }

                // Days
                VStack(alignment: .leading, spacing: 10) {
                    Text("DAYS OF THE WEEK")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    if existingSchedule != nil && !modifyAllDays, let singleDay = initialDay {
                        Text(dayName(for: singleDay))
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    } else {
                        HStack(spacing: 12) {
                            ForEach(dayOrder, id: \.self) { day in
                                DayToggle(day: day, isSelected: days.contains(day)) {
                                    if days.contains(day) {
                                        days.remove(day)
                                    } else {
                                        days.insert(day)
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 10)

                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: saveSchedule) {
                        Text(existingSchedule == nil ? (sessionType == .focus ? "Add Focus Session" : "Add Break Session") : "Save Changes")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(sessionType == .focus ? FocusColor.color(for: appState.accentColorIndex) : .orange)
                    .disabled(days.isEmpty && modifyAllDays)

                    if existingSchedule != nil {
                        Button(action: deleteSchedule) {
                            Text("Delete Schedule")
                                .foregroundColor(.red)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(25)
        }
        .frame(width: 500, height: 650)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if let schedule = existingSchedule {
                name = schedule.name
                days = schedule.days
                startTime = schedule.startTime
                endTime = schedule.endTime
                selectedColorIndex = schedule.colorIndex
                sessionType = schedule.type
            } else {
                // New schedule
                name = ""
                sessionType = .focus
                selectedColorIndex = (appState.schedules.count % FocusColor.all.count)
                if let day = initialDay {
                    days = [day]
                } else {
                    days = [2, 3, 4, 5, 6] // Default to work week for manual add
                }

                if let start = initialStartTime {
                    startTime = start
                    if let end = initialEndTime {
                        endTime = end
                    } else {
                        endTime = Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? start
                    }
                } else {
                    // Default to 9-5
                    let cal = Calendar.current
                    var startComp = DateComponents()
                    startComp.hour = 9
                    startComp.minute = 0
                    var endComp = DateComponents()
                    endComp.hour = 17
                    endComp.minute = 0

                    startTime = cal.date(from: startComp) ?? Date()
                    endTime = cal.date(from: endComp) ?? Date()
                }
            }
        }
    }

    func saveSchedule() {
        let finalName = name.trimmingCharacters(in: .whitespaces).isEmpty ? (sessionType == .focus ? "Focus Session" : "Break Session") : name

        if let schedule = existingSchedule,
           let index = appState.schedules.firstIndex(where: { $0.id == schedule.id }) {

            if modifyAllDays {
                appState.schedules[index].name = finalName
                appState.schedules[index].days = days
                appState.schedules[index].startTime = startTime
                appState.schedules[index].endTime = endTime
                appState.schedules[index].colorIndex = selectedColorIndex
                appState.schedules[index].type = sessionType
            } else if let dayToRemove = initialDay {
                appState.schedules[index].days.remove(dayToRemove)
                if appState.schedules[index].days.isEmpty {
                    appState.schedules.remove(at: index)
                }
                let newSchedule = Schedule(name: finalName, days: [dayToRemove], startTime: startTime, endTime: endTime, colorIndex: selectedColorIndex, type: sessionType)
                appState.schedules.append(newSchedule)
            }
        } else {
            let newSchedule = Schedule(
                name: finalName,
                days: days,
                startTime: startTime,
                endTime: endTime,
                colorIndex: selectedColorIndex,
                type: sessionType
            )
            appState.schedules.append(newSchedule)
        }
        isPresented = false
    }

    func deleteSchedule() {
        if let schedule = existingSchedule,
           let index = appState.schedules.firstIndex(where: { $0.id == schedule.id }) {
            if !modifyAllDays, let dayToRemove = initialDay {
                appState.schedules[index].days.remove(dayToRemove)
                if appState.schedules[index].days.isEmpty {
                    appState.schedules.remove(at: index)
                }
            } else {
                appState.schedules.remove(at: index)
            }
            isPresented = false
        }
    }

    func dayName(for day: Int) -> String {
        return Calendar.current.weekdaySymbols[day - 1]
    }
}

struct DayToggle: View {
    @EnvironmentObject var appState: AppState
    let day: Int
    let isSelected: Bool
    let action: () -> Void

    let dayNames = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        Button(action: action) {
            Text(dayNames[day - 1])
                .font(.title3.bold())
                .frame(width: 45, height: 45)
                .background(isSelected ? FocusColor.color(for: appState.accentColorIndex) : Color.secondary.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
