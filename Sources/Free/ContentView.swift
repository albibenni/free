import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    @State private var showRules = false
    @State private var showSchedules = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            FocusView(showRules: $showRules, showSchedules: $showSchedules)
            
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .frame(minWidth: 450, minHeight: 600)
        .sheet(isPresented: $showSettings) {
            SheetWrapper(title: "Settings", isPresented: $showSettings) {
                SettingsView()
            }
            .frame(width: 400, height: 350)
        }
        .sheet(isPresented: $showRules) {
            SheetWrapper(title: "Allowed Websites", isPresented: $showRules) {
                RulesView()
            }
            .frame(width: 550, height: 650)
        }
        .sheet(isPresented: $showSchedules) {
            SheetWrapper(title: "Focus Schedules", isPresented: $showSchedules) {
                SchedulesView()
            }
            .frame(width: 500, height: 600)
        }
    }
}

struct SheetWrapper<Content: View>: View {
    let title: String
    @Binding var isPresented: Bool
    let content: Content

    init(title: String, isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.title = title
        self._isPresented = isPresented
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            content
        }
    }
}

struct FocusView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showRules: Bool
    @Binding var showSchedules: Bool
    @State private var showCustomTimer = false
    @State private var customMinutesString = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Permission Warning
            if !appState.isTrusted {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.white)
                    Text("Accessibility Permission Needed")
                        .foregroundColor(.white)
                        .bold()
                    Spacer()
                    Button("Grant") {
                        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                        AXIsProcessTrustedWithOptions(options)
                    }
                    .foregroundColor(.black)
                    .padding(6)
                    .background(Color.white)
                    .cornerRadius(8)
                }
                .padding()
                .background(Color.red)
                .cornerRadius(12)
            }

            // Header
            HStack {
                Image(systemName: "leaf.fill")
                    .font(.largeTitle)
                    .foregroundColor(appState.isBlocking && !appState.isPaused ? .green : .gray)
                VStack(alignment: .leading) {
                    Text("Focus Mode")
                        .font(.title2)
                        .bold()
                    Text(appState.isBlocking ? (appState.isPaused ? "Paused" : "Active") : "Inactive")
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { appState.isBlocking },
                    set: { _ in appState.toggleBlocking() }
                ))
                    .toggleStyle(.switch)
                    .disabled(appState.isBlocking && appState.isUnblockable)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            if appState.isBlocking && appState.isUnblockable {
                Text("Unblockable mode is active. You cannot disable Focus Mode.")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal)
            }
            
            // Pause / Break Dashboard
            if appState.isBlocking {
                if appState.isPaused {
                    VStack(spacing: 10) {
                        Text("On Break")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(appState.timeString(time: appState.pauseRemaining))
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                        
                        Button(action: { appState.cancelPause() }) {
                            Text("End Break & Focus")
                                .font(.headline)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                } else {
                    VStack(alignment: .leading) {
                        Text("Take a break:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Button("5m") { appState.startPause(minutes: 5) }
                            Button("15m") { appState.startPause(minutes: 15) }
                            Button("30m") { appState.startPause(minutes: 30) }
                            Button("Custom") { showCustomTimerInput() }
                        }
                    }
                }
            }
            
            // Schedules Widget (Card)
            Button(action: { showSchedules = true }) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.headline)
                            .foregroundColor(.purple)
                        Text("Focus Schedules")
                            .font(.headline)
                        Spacer()
                        Text("\(appState.schedules.count)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(10)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if appState.schedules.isEmpty {
                        Text("No schedules set. Click to automate.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(appState.schedules.prefix(2)) { schedule in
                                HStack {
                                    Circle()
                                        .fill(schedule.isEnabled ? Color.green : Color.gray)
                                        .frame(width: 6, height: 6)
                                    Text(schedule.name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            if appState.schedules.count > 2 {
                                Text("and \(appState.schedules.count - 2) more...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // Rules Widget (Card)
            Button(action: { showRules = true }) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "globe")
                            .font(.headline)
                            .foregroundColor(.blue)
                        Text("Allowed Websites")
                            .font(.headline)
                        Spacer()
                        Text("\(appState.allowedRules.count)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(10)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if appState.allowedRules.isEmpty {
                        Text("No websites allowed. Click to add.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(appState.allowedRules.prefix(3), id: \.self) { rule in
                                Text("• \(rule)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            if appState.allowedRules.count > 3 {
                                Text("and \(appState.allowedRules.count - 3) more...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding()
        .alert("Custom Break", isPresented: $showCustomTimer) {
            TextField("Minutes", text: $customMinutesString)
            Button("Start") {
                if let minutes = Double(customMinutesString) {
                    appState.startPause(minutes: minutes)
                }
                customMinutesString = ""
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter duration in minutes:")
        }
    }

    func showCustomTimerInput() {
        showCustomTimer = true
    }
}

struct RulesView: View {
    @EnvironmentObject var appState: AppState
    @State private var newRule: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            List {
                ForEach(appState.allowedRules, id: \.self) { rule in
                    HStack {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(rule)
                            .font(.subheadline)
                        Spacer()
                        Button(action: {
                            if let index = appState.allowedRules.firstIndex(of: rule) {
                                appState.allowedRules.remove(at: index)
                            }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(PlainListStyle())
            .background(Color.clear)

            HStack {
                TextField("Add URL to allow...", text: $newRule, onCommit: addRule)
                    .textFieldStyle(.roundedBorder)
                    .padding(.leading, 8) // Extra padding to clear rounded corners
                
                Button(action: addRule) {
                    Image(systemName: "plus")
                        .padding(.horizontal, 8)
                }
                .disabled(newRule.isEmpty)
                .buttonStyle(.borderedProminent)
                .padding(.trailing, 8) // Extra padding to clear rounded corners
            }
            .padding(.bottom, 8)
        }
        .padding() // Main padding for the sheet content
    }

    func addRule() {
        let cleanedRule = newRule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedRule.isEmpty else { return }
        
        if !appState.allowedRules.contains(cleanedRule) {
            appState.allowedRules.append(cleanedRule)
        }
        
        DispatchQueue.main.async {
            self.newRule = ""
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showChallenge = false
    @State private var challengeInput = ""
    let challengePhrase = "I am choosing to break my focus and I acknowledge that this may impact my productivity."

    var body: some View {
        Form {
            Section {
                if appState.isBlocking && appState.isUnblockable {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unblockable Mode")
                                .font(.headline)
                            Text("Active and Locking Focus Mode.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        Spacer()
                        Button("Disable...") {
                            showChallenge = true
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Toggle(isOn: $appState.isUnblockable) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unblockable Mode")
                                .font(.headline)
                            Text("When active, you cannot disable Focus Mode.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
            } header: {
                Text("Strict Mode")
            }
            
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .alert("Emergency Unlock", isPresented: $showChallenge) {
            TextField("Type the phrase exactly", text: $challengeInput)
            Button("Unlock", role: .destructive) {
                if challengeInput == challengePhrase {
                    appState.isUnblockable = false
                }
                challengeInput = ""
            }
            Button("Cancel", role: .cancel) { 
                challengeInput = ""
            }
        } message: {
            Text("To disable Unblockable Mode, you must type the following exactly:\n\n\"\(challengePhrase)\"")
        }
    }
}

struct SchedulesView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddSchedule = false
    @State private var viewMode = 0 // 0 = List, 1 = Calendar
    
    // For passing data from Calendar click
    @State private var selectedDay: Int?
    @State private var selectedTime: Date?

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
                        ScheduleRow(schedule: $schedule)
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
                    selectedTime: $selectedTime
                )
            }
            
            Divider()
            
            Button(action: { 
                // Reset defaults for manual add
                selectedDay = nil
                selectedTime = nil
                showingAddSchedule = true 
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Schedule")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding()
        }
        .sheet(isPresented: $showingAddSchedule) {
            AddScheduleView(
                isPresented: $showingAddSchedule,
                initialDay: selectedDay,
                initialStartTime: selectedTime
            )
        }
    }
}

struct ScheduleRow: View {
    @Binding var schedule: Schedule

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(schedule.name)
                    .font(.headline)
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
            Toggle("", isOn: $schedule.isEnabled)
                .toggleStyle(.switch)
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
    
    @State private var name = ""
    @State private var days: Set<Int> = [2, 3, 4, 5, 6]
    @State private var startTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var endTime = Calendar.current.date(from: DateComponents(hour: 17, minute: 0)) ?? Date()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    TextField("Name", text: $name)
                }
                
                Section(header: Text("Schedule")) {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                }
                
                Section(header: Text("Days")) {
                    HStack {
                        ForEach(1...7, id: \.self) { day in
                            DayToggle(day: day, isSelected: days.contains(day)) {
                                if days.contains(day) {
                                    days.remove(day)
                                } else {
                                    days.insert(day)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Schedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let newSchedule = Schedule(
                            name: name.isEmpty ? "Focus Session" : name,
                            days: days,
                            startTime: startTime,
                            endTime: endTime
                        )
                        appState.schedules.append(newSchedule)
                        isPresented = false
                    }
                    .disabled(days.isEmpty)
                }
            }
        }
        .frame(width: 400, height: 450)
        .onAppear {
            if let day = initialDay {
                days = [day]
            }
            if let start = initialStartTime {
                startTime = start
                // Default duration 1 hour
                endTime = Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? start
            }
        }
    }
}

struct DayToggle: View {
    let day: Int
    let isSelected: Bool
    let action: () -> Void
    
    let dayNames = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        Button(action: action) {
            Text(dayNames[day - 1])
                .font(.caption.bold())
                .frame(width: 30, height: 30)
                .background(isSelected ? Color.blue : Color.secondary.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}