import SwiftUI

struct AddScheduleView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    var initialDay: Int?, initialStartTime: Date?, initialEndTime: Date?, existingSchedule: Schedule?, editorContext: ScheduleEditorContext?

    @State private var name: String
    @State private var days: Set<Int>
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var selectedColorIndex: Int
    @State private var sessionType: ScheduleType
    @State private var ruleSetId: UUID?
    @State private var modifyAllDays = true
    @State private var isRecurring = false

    init(isPresented: Binding<Bool>, initialDay: Int? = nil, initialStartTime: Date? = nil, initialEndTime: Date? = nil, existingSchedule: Schedule? = nil, editorContext: ScheduleEditorContext? = nil) {
        self._isPresented = isPresented ; self.initialDay = initialDay ; self.initialStartTime = initialStartTime
        self.initialEndTime = initialEndTime ; self.existingSchedule = existingSchedule ; self.editorContext = editorContext
        let c = AddScheduleView.configure(initialDay: initialDay, initialStartTime: initialStartTime, initialEndTime: initialEndTime, existingSchedule: existingSchedule)
        _name = State(initialValue: c.name) ; _days = State(initialValue: c.days) ; _startTime = State(initialValue: c.startTime)
        _endTime = State(initialValue: c.endTime) ; _selectedColorIndex = State(initialValue: c.colorIndex)
        _sessionType = State(initialValue: c.type) ; _ruleSetId = State(initialValue: c.ruleSetId)
        _isRecurring = State(initialValue: c.isRecurring)
    }

    var body: some View {
        VStack(spacing: 0) {
            header.padding(25)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section("SESSION TYPE") {
                        Picker("", selection: $sessionType) {
                            ForEach(ScheduleType.allCases, id: \.self) { type in
                                Label(type.rawValue, systemImage: type == .focus ? "target" : "cup.and.saucer.fill").tag(type)
                            }
                        }.pickerStyle(.segmented)
                    }
                    if sessionType == .focus {
                        section("ALLOWED LIST") {
                            Picker("", selection: $ruleSetId) {
                                Text("None").tag(UUID?.none) ; Divider()
                                ForEach(appState.ruleSets) { Text($0.name).tag(UUID?.some($0.id)) }
                            }
                        }
                    }
                    if existingSchedule != nil && initialDay != nil && (existingSchedule?.days.count ?? 0) > 1 {
                        section("EDIT SCOPE") {
                            Picker("", selection: $modifyAllDays) {
                                Text("All Days").tag(true) ; Text("Only \(dayName(for: initialDay!))").tag(false)
                            }.pickerStyle(.segmented)
                        }
                    }
                    section("SCHEDULE NAME") { TextField(sessionType == .focus ? "Focus Session" : "Break Session", text: $name).textFieldStyle(.roundedBorder).font(.title3) }
                    section("THEME COLOR") {
                        HStack(spacing: 12) {
                            ForEach(0..<FocusColor.all.count, id: \.self) { i in
                                Circle().fill(FocusColor.all[i]).frame(width: 30, height: 30)
                                    .overlay(Circle().stroke(Color.primary, lineWidth: selectedColorIndex == i ? 2 : 0).padding(-4))
                                    .onTapGesture { selectedColorIndex = i }
                            }
                        }
                    }
                    HStack(spacing: 40) {
                        section("START TIME") { DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute).labelsHidden().datePickerStyle(.field).scaleEffect(1.1).frame(width: 90, height: 35) }
                        section("END TIME") { DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute).labelsHidden().datePickerStyle(.field).scaleEffect(1.1).frame(width: 90, height: 35) }
                    }
                    
                    Toggle("Repeat weekly", isOn: $isRecurring)
                        .toggleStyle(.checkbox)
                        .font(.headline)
                    
                    if isRecurring {
                        section("DAYS OF THE WEEK") {
                            if existingSchedule != nil && !modifyAllDays, let d = initialDay {
                                Text(dayName(for: d)).font(.headline).padding(.horizontal, 16).padding(.vertical, 8).background(Color.blue.opacity(0.1)).cornerRadius(8)
                            } else {
                                HStack(spacing: 12) {
                                    let order = appState.weekStartsOnMonday ? [2, 3, 4, 5, 6, 7, 1] : [1, 2, 3, 4, 5, 6, 7]
                                    ForEach(order, id: \.self) { d in DayToggle(day: d, isSelected: days.contains(d)) { if days.contains(d) { days.remove(d) } else { days.insert(d) } } }
                                }
                            }
                        }
                    }
                    VStack(spacing: 12) {
                        Button(action: save) { Text(existingSchedule == nil ? (sessionType == .focus ? "Add Focus Session" : "Add Break Session") : "Save Changes") }
                            .buttonStyle(AppPrimaryButtonStyle(color: sessionType == .focus ? FocusColor.color(for: appState.accentColorIndex) : .orange, maxWidth: .infinity, isProminent: true))
                            .disabled(days.isEmpty && modifyAllDays)
                        if existingSchedule != nil {
                            Button(action: delete) { Text("Delete Schedule").foregroundColor(.red).font(.subheadline).frame(maxWidth: .infinity) }.buttonStyle(.plain)
                        }
                    }
                }.padding(25)
            }
        }.frame(width: 500, height: 650).background(Color(NSColor.windowBackgroundColor))
        .onAppear { if existingSchedule == nil { selectedColorIndex = (appState.schedules.count % FocusColor.all.count) ; ruleSetId = appState.ruleSets.first?.id } }
    }

    // MARK: - Components
    private var header: some View {
        HStack {
            Text(existingSchedule == nil ? "New Schedule" : "Edit Schedule").font(.title2).bold() ; Spacer()
            Button(action: { isPresented = false }) { Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.secondary) }.buttonStyle(.plain)
        }
    }

    private func section<V: View>(_ title: String, @ViewBuilder content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.bold()).foregroundColor(.secondary)
            content()
        }
    }

    // MARK: - Logic
    private func save() {
        var finalDate: Date? = nil
        var finalDays = days
        
        if !isRecurring {
            if let targetDate = Schedule.calculateOneOffDate(
                initialDay: initialDay,
                weekOffset: editorContext?.weekOffset ?? 0,
                weekStartsOnMonday: appState.weekStartsOnMonday
            ) {
                finalDate = targetDate
                finalDays = [Calendar.current.component(.weekday, from: targetDate)]
            }
        }
        
        appState.saveSchedule(name: name, days: finalDays, date: finalDate, start: startTime, end: endTime, color: selectedColorIndex, type: sessionType, ruleSet: ruleSetId, existingId: existingSchedule?.id, modifyAllDays: modifyAllDays, initialDay: initialDay)
        isPresented = false
    }
    private func delete() {
        if let s = existingSchedule { appState.deleteSchedule(id: s.id, modifyAllDays: modifyAllDays, initialDay: initialDay) }
        isPresented = false
    }
    private func dayName(for day: Int) -> String { Calendar.current.weekdaySymbols[day - 1] }

    struct Configuration { let name: String; let days: Set<Int>; let isRecurring: Bool; let startTime: Date; let endTime: Date; let colorIndex: Int; let type: ScheduleType; let ruleSetId: UUID? }
    static func configure(initialDay: Int?, initialStartTime: Date?, initialEndTime: Date?, existingSchedule: Schedule?) -> Configuration {
        if let s = existingSchedule { return Configuration(name: s.name, days: s.days, isRecurring: s.date == nil, startTime: s.startTime, endTime: s.endTime, colorIndex: s.colorIndex, type: s.type, ruleSetId: s.ruleSetId) }
        let start = initialStartTime ?? Calendar.current.date(from: DateComponents(hour: 9, minute: 0))!
        let end = initialEndTime ?? Calendar.current.date(byAdding: .hour, value: 1, to: start)!
        return Configuration(name: "", days: initialDay.map { [$0] } ?? [2,3,4,5,6], isRecurring: false, startTime: start, endTime: end, colorIndex: 0, type: .focus, ruleSetId: nil)
    }
}

struct DayToggle: View {
    @EnvironmentObject var appState: AppState
    let day: Int, isSelected: Bool, action: () -> Void
    let dayNames = ["S", "M", "T", "W", "T", "F", "S"]
    var body: some View {
        Button(action: action) {
            Text(dayNames[day - 1]).font(.title3.bold()).frame(width: 45, height: 45)
                .background(isSelected ? FocusColor.color(for: appState.accentColorIndex) : Color.secondary.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary).clipShape(Circle())
        }.buttonStyle(.plain)
    }
}
