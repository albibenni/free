import SwiftUI

struct AddScheduleView: View {
    @EnvironmentObject private var environmentAppState: AppState
    @Binding var isPresented: Bool
    var initialDay: Int?, initialStartTime: Date?, initialEndTime: Date?,
        existingSchedule: Schedule?, editorContext: ScheduleEditorContext?
    private let actionAppState: AppState?
    var appState: AppState { actionAppState ?? environmentAppState }

    @State private var name: String
    @State private var days: Set<Int>
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var selectedColorIndex: Int
    @State private var sessionType: ScheduleType
    @State private var ruleSetId: UUID?
    @State private var modifyAllDays = true
    @State private var isRecurring = false

    init(
        isPresented: Binding<Bool>,
        initialDay: Int? = nil,
        initialStartTime: Date? = nil,
        initialEndTime: Date? = nil,
        existingSchedule: Schedule? = nil,
        editorContext: ScheduleEditorContext? = nil,
        initialModifyAllDays: Bool = true,
        initialIsRecurring: Bool? = nil,
        initialSessionType: ScheduleType? = nil,
        actionAppState: AppState? = nil
    ) {
        self._isPresented = isPresented
        self.initialDay = initialDay
        self.initialStartTime = initialStartTime
        self.initialEndTime = initialEndTime
        self.existingSchedule = existingSchedule
        self.editorContext = editorContext
        self.actionAppState = actionAppState
        let c = ScheduleEditorSupport.configuration(
            initialDay: initialDay, initialStartTime: initialStartTime,
            initialEndTime: initialEndTime, existingSchedule: existingSchedule)
        _name = State(initialValue: c.name)
        _days = State(initialValue: c.days)
        _startTime = State(initialValue: c.startTime)
        _endTime = State(initialValue: c.endTime)
        _selectedColorIndex = State(initialValue: c.colorIndex)
        _sessionType = State(initialValue: initialSessionType ?? c.type)
        _ruleSetId = State(initialValue: c.ruleSetId)
        _modifyAllDays = State(initialValue: initialModifyAllDays)
        _isRecurring = State(initialValue: initialIsRecurring ?? c.isRecurring)
    }

    var body: some View {
        VStack(spacing: 0) {
            header.padding(25)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    let importedSchedule = Self.isImportedSchedule(existingSchedule)

                    if importedSchedule {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.secondary)
                            Text("Imported from Calendar")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(8)
                    }
                    if importedSchedule {
                        section("SCHEDULE NAME") {
                            TextField(Self.scheduleNamePlaceholder(for: sessionType), text: $name)
                                .textFieldStyle(.roundedBorder)
                                .font(.title3)
                                .disabled(true)
                        }
                    }
                    section("SESSION TYPE") {
                        Picker("", selection: $sessionType) {
                            ForEach(ScheduleType.allCases, id: \.self) { type in
                                Label(
                                    type.rawValue,
                                    systemImage: type == .focus ? "target" : "cup.and.saucer.fill"
                                ).tag(type)
                            }
                        }.pickerStyle(.segmented)
                    }
                    if Self.shouldShowAllowedList(for: sessionType) {
                        section("ALLOWED LIST") {
                            Picker("", selection: $ruleSetId) {
                                Text("None").tag(UUID?.none)
                                Divider()
                                ForEach(appState.ruleSets) { Text($0.name).tag(UUID?.some($0.id)) }
                            }
                        }
                    }
                    if Self.canEditImportedScheduleDetails(existingSchedule: existingSchedule) {
                        if Self.shouldShowEditScope(
                            existingSchedule: existingSchedule, initialDay: initialDay)
                        {
                            section("EDIT SCOPE") {
                                Picker("", selection: $modifyAllDays) {
                                    Text("All Days").tag(true)
                                    Text("Only \(Self.dayName(for: initialDay!))").tag(false)
                                }.pickerStyle(.segmented)
                            }
                        }
                        section("SCHEDULE NAME") {
                            TextField(Self.scheduleNamePlaceholder(for: sessionType), text: $name)
                                .textFieldStyle(.roundedBorder)
                                .font(.title3)
                        }
                    }
                    section("THEME COLOR") {
                        AddScheduleThemeColorRow(selectedColorIndex: $selectedColorIndex)
                    }
                    if Self.canEditImportedScheduleDetails(existingSchedule: existingSchedule) {
                        HStack(spacing: 40) {
                            section("START TIME") {
                                DatePicker(
                                    "", selection: $startTime, displayedComponents: .hourAndMinute
                                ).labelsHidden().datePickerStyle(.field).scaleEffect(1.1).frame(
                                    width: 90, height: 35)
                            }
                            section("END TIME") {
                                DatePicker(
                                    "", selection: $endTime, displayedComponents: .hourAndMinute
                                )
                                .labelsHidden().datePickerStyle(.field).scaleEffect(1.1).frame(
                                    width: 90, height: 35)
                            }
                        }

                        Toggle("Repeat weekly", isOn: $isRecurring)
                            .toggleStyle(.checkbox)
                            .font(.headline)

                        if isRecurring {
                            section("DAYS OF THE WEEK") {
                                AddScheduleRecurringDaysRow(
                                    existingSchedule: existingSchedule,
                                    modifyAllDays: modifyAllDays,
                                    initialDay: initialDay,
                                    days: $days
                                )
                                .environmentObject(appState)
                            }
                        }
                    }
                    VStack(spacing: 12) {
                        Button(action: performSaveAction) {
                            Text(
                                Self.saveButtonTitle(
                                    existingSchedule: existingSchedule, sessionType: sessionType))
                        }
                        .buttonStyle(
                            AppPrimaryButtonStyle(
                                color: Self.primaryButtonColor(
                                    sessionType: sessionType,
                                    accentColorIndex: appState.accentColorIndex),
                                maxWidth: .infinity, isProminent: true)
                        )
                        .disabled(
                            Self.isSaveDisabled(
                                days: days,
                                modifyAllDays: modifyAllDays,
                                isRecurring: isRecurring
                            )
                        )
                        if Self.canDeleteSchedule(existingSchedule: existingSchedule) {
                            Button(action: performDeleteAction) {
                                Text("Delete Schedule").foregroundColor(.red).font(.subheadline)
                                    .frame(maxWidth: .infinity)
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(25)
            }
        }.frame(width: 500, height: 650).background(Color(NSColor.windowBackgroundColor))
            .onAppear {
                if Self.shouldApplyNewScheduleDefaults(existingSchedule: existingSchedule) {
                    selectedColorIndex = (appState.schedules.count % FocusColor.all.count)
                    ruleSetId = appState.ruleSets.first?.id
                }
            }
    }

    private var header: some View {
        HStack {
            Text(existingSchedule == nil ? "New Schedule" : "Edit Schedule").font(.title2).bold()
            Spacer()
            Button(action: dismissAction) {
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.secondary)
            }.buttonStyle(.plain)
        }
    }

    private func section<V: View>(_ title: String, @ViewBuilder content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.bold()).foregroundColor(.secondary)
            content()
        }
    }

    func performSaveAction() {
        performSave(using: appState)
    }

    func performDeleteAction() {
        performDelete(using: appState)
    }

    func dismissAction() {
        isPresented = false
    }

    func performSave(using appState: AppState) {
        let payload = Self.savePayload(
            days: days,
            isRecurring: isRecurring,
            initialDay: initialDay,
            weekOffset: editorContext?.weekOffset ?? 0,
            weekStartsOnMonday: appState.weekStartsOnMonday
        )
        appState.saveSchedule(
            name: name, days: payload.days, date: payload.date, start: startTime, end: endTime,
            color: selectedColorIndex, type: sessionType, ruleSet: ruleSetId,
            existingId: existingSchedule?.id, modifyAllDays: modifyAllDays, initialDay: initialDay)
        isPresented = false
    }
    func performDelete(using appState: AppState) {
        if let s = existingSchedule {
            appState.deleteSchedule(id: s.id, modifyAllDays: modifyAllDays, initialDay: initialDay)
        }
        isPresented = false
    }
    static func dayName(for day: Int) -> String { ScheduleEditorSupport.dayName(for: day) }
    static func canEditImportedScheduleDetails(existingSchedule: Schedule?) -> Bool {
        ScheduleEditorSupport.canEditImportedScheduleDetails(existingSchedule: existingSchedule)
    }

    typealias Configuration = ScheduleEditorSupport.Configuration
    static func configure(
        initialDay: Int?, initialStartTime: Date?, initialEndTime: Date?,
        existingSchedule: Schedule?
    ) -> Configuration {
        ScheduleEditorSupport.configuration(
            initialDay: initialDay,
            initialStartTime: initialStartTime,
            initialEndTime: initialEndTime,
            existingSchedule: existingSchedule
        )
    }

    typealias SavePayload = ScheduleEditorSupport.SavePayload

    static func savePayload(
        days: Set<Int>, isRecurring: Bool, initialDay: Int?, weekOffset: Int,
        weekStartsOnMonday: Bool
    ) -> SavePayload {
        ScheduleEditorSupport.savePayload(
            days: days,
            isRecurring: isRecurring,
            initialDay: initialDay,
            weekOffset: weekOffset,
            weekStartsOnMonday: weekStartsOnMonday
        )
    }

    static func shouldShowAllowedList(for sessionType: ScheduleType) -> Bool {
        ScheduleEditorSupport.shouldShowAllowedList(for: sessionType)
    }

    static func isImportedSchedule(_ existingSchedule: Schedule?) -> Bool {
        ScheduleEditorSupport.isImportedSchedule(existingSchedule)
    }

    static func canDeleteSchedule(existingSchedule: Schedule?) -> Bool {
        ScheduleEditorSupport.canDeleteSchedule(existingSchedule: existingSchedule)
    }

    static func shouldShowEditScope(existingSchedule: Schedule?, initialDay: Int?) -> Bool {
        ScheduleEditorSupport.shouldShowEditScope(
            existingSchedule: existingSchedule,
            initialDay: initialDay
        )
    }

    static func scheduleNamePlaceholder(for sessionType: ScheduleType) -> String {
        ScheduleEditorSupport.scheduleNamePlaceholder(for: sessionType)
    }

    static func shouldShowSingleDayBadge(
        existingSchedule: Schedule?, modifyAllDays: Bool, initialDay: Int?
    ) -> Bool {
        ScheduleEditorSupport.shouldShowSingleDayBadge(
            existingSchedule: existingSchedule,
            modifyAllDays: modifyAllDays,
            initialDay: initialDay
        )
    }

    static func weekDayOrder(weekStartsOnMonday: Bool) -> [Int] {
        ScheduleEditorSupport.weekDayOrder(weekStartsOnMonday: weekStartsOnMonday)
    }

    static func toggledDays(_ days: Set<Int>, day: Int) -> Set<Int> {
        ScheduleEditorSupport.toggledDays(days, day: day)
    }

    static func saveButtonTitle(existingSchedule: Schedule?, sessionType: ScheduleType) -> String {
        ScheduleEditorSupport.saveButtonTitle(
            existingSchedule: existingSchedule,
            sessionType: sessionType
        )
    }

    static func primaryButtonColor(sessionType: ScheduleType, accentColorIndex: Int) -> Color {
        Color(
            ScheduleEditorSupport.primaryButtonColor(
                sessionType: sessionType,
                accentColorIndex: accentColorIndex
            )
        )
    }

    static func isSaveDisabled(days: Set<Int>, modifyAllDays: Bool, isRecurring: Bool) -> Bool {
        ScheduleEditorSupport.isSaveDisabled(
            days: days,
            modifyAllDays: modifyAllDays,
            isRecurring: isRecurring
        )
    }

    static func shouldApplyNewScheduleDefaults(existingSchedule: Schedule?) -> Bool {
        ScheduleEditorSupport.shouldApplyNewScheduleDefaults(existingSchedule: existingSchedule)
    }
}

struct DayToggle: View {
    @EnvironmentObject var appState: AppState
    let day: Int, isSelected: Bool, action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(Self.daySymbol(at: day)).font(.title3.bold()).frame(width: 45, height: 45)
                .background(
                    Self.backgroundColor(
                        isSelected: isSelected, accentColorIndex: appState.accentColorIndex)
                )
                .foregroundColor(Self.foregroundColor(isSelected: isSelected)).clipShape(Circle())
        }.buttonStyle(.plain)
    }

    static func daySymbol(at index: Int) -> String {
        ScheduleEditorSupport.daySymbol(at: index)
    }

    static func backgroundColor(isSelected: Bool, accentColorIndex: Int) -> Color {
        isSelected ? FocusColor.color(for: accentColorIndex) : Color.secondary.opacity(0.2)
    }

    static func foregroundColor(isSelected: Bool) -> Color {
        isSelected ? .white : .primary
    }
}
