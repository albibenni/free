import SwiftUI

struct AddScheduleView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool

    // Optional initializers
    var initialDay: Int?
    var initialStartTime: Date?
    var initialEndTime: Date?
    var existingSchedule: Schedule?

    @State private var name: String
    @State private var days: Set<Int>
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var selectedColorIndex: Int
    @State private var sessionType: ScheduleType
    @State private var ruleSetId: UUID?

    // Logic for splitting schedule
    @State private var modifyAllDays = true

    init(isPresented: Binding<Bool>, initialDay: Int? = nil, initialStartTime: Date? = nil, initialEndTime: Date? = nil, existingSchedule: Schedule? = nil) {
        self._isPresented = isPresented
        self.initialDay = initialDay
        self.initialStartTime = initialStartTime
        self.initialEndTime = initialEndTime
        self.existingSchedule = existingSchedule

        if let schedule = existingSchedule {
            _name = State(initialValue: schedule.name)
            _days = State(initialValue: schedule.days)
            _startTime = State(initialValue: schedule.startTime)
            _endTime = State(initialValue: schedule.endTime)
            _selectedColorIndex = State(initialValue: schedule.colorIndex)
            _sessionType = State(initialValue: schedule.type)
            _ruleSetId = State(initialValue: schedule.ruleSetId)
        } else {
            _name = State(initialValue: "")
            _sessionType = State(initialValue: .focus)
            _selectedColorIndex = State(initialValue: 0)
            _ruleSetId = State(initialValue: nil)
            
            if let day = initialDay {
                _days = State(initialValue: [day])
            } else {
                _days = State(initialValue: [2, 3, 4, 5, 6])
            }

            if let start = initialStartTime {
                _startTime = State(initialValue: start)
                if let end = initialEndTime {
                    _endTime = State(initialValue: end)
                } else {
                    _endTime = State(initialValue: Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? start)
                }
            } else {
                let cal = Calendar.current
                var startComp = DateComponents()
                startComp.hour = 9
                startComp.minute = 0
                var endComp = DateComponents()
                endComp.hour = 17
                endComp.minute = 0
                _startTime = State(initialValue: cal.date(from: startComp) ?? Date())
                _endTime = State(initialValue: cal.date(from: endComp) ?? Date())
            }
        }
    }

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

            ScrollView {
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

                    if sessionType == .focus {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ALLOWED LIST")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)

                            Picker("", selection: $ruleSetId) {
                                Text("None").tag(UUID?.none)
                                Divider()
                                ForEach(appState.ruleSets) { set in
                                    Text(set.name).tag(UUID?.some(set.id))
                                }
                            }
                        }
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
                        .keyboardShortcut(.defaultAction)

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
        }
        .frame(width: 500, height: 650)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if existingSchedule == nil {
                selectedColorIndex = (appState.schedules.count % FocusColor.all.count)
                ruleSetId = appState.ruleSets.first?.id
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
                appState.schedules[index].ruleSetId = ruleSetId
            } else if let dayToRemove = initialDay {
                appState.schedules[index].days.remove(dayToRemove)
                if appState.schedules[index].days.isEmpty {
                    appState.schedules.remove(at: index)
                }
                let newSchedule = Schedule(name: finalName, days: [dayToRemove], startTime: startTime, endTime: endTime, colorIndex: selectedColorIndex, type: sessionType, ruleSetId: ruleSetId)
                appState.schedules.append(newSchedule)
            }
        } else {
            let newSchedule = Schedule(
                name: finalName,
                days: days,
                startTime: startTime,
                endTime: endTime,
                colorIndex: selectedColorIndex,
                type: sessionType,
                ruleSetId: ruleSetId
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
