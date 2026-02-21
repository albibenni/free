import SwiftUI

struct RulesView: View {
    @EnvironmentObject private var environmentAppState: AppState
    @Environment(\.colorScheme) var colorScheme
    private let actionAppState: AppState?
    @State private var selectedSetId: UUID?
    @State private var newRule: String = ""
    @State private var showAddSetAlert = false
    @State private var newSetName = ""
    @State private var isSidebarVisible = true
    @State private var isSuggestionsExpanded = false
    var appState: AppState { actionAppState ?? environmentAppState }

    init(
        initialSelectedSetId: UUID? = nil,
        initialNewRule: String = "",
        initialShowAddSetAlert: Bool = false,
        initialNewSetName: String = "",
        initialSidebarVisible: Bool = true,
        initialSuggestionsExpanded: Bool = false,
        actionAppState: AppState? = nil
    ) {
        self.actionAppState = actionAppState
        _selectedSetId = State(initialValue: initialSelectedSetId)
        _newRule = State(initialValue: initialNewRule)
        _showAddSetAlert = State(initialValue: initialShowAddSetAlert)
        _newSetName = State(initialValue: initialNewSetName)
        _isSidebarVisible = State(initialValue: initialSidebarVisible)
        _isSuggestionsExpanded = State(initialValue: initialSuggestionsExpanded)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebarView
            mainContentView
        }
        .frame(minWidth: 700, minHeight: 600)
        .onAppear(perform: handleOnAppear)
        .alert("New Allowed List", isPresented: $showAddSetAlert) {
            TextField("List Name", text: $newSetName)
            Button("Create", action: createSet)
            Button("Cancel", role: .cancel, action: cancelCreateSet)
        }
    }

    @ViewBuilder
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isSidebarVisible {
                HStack {
                    Text("ALLOWED LISTS").font(.caption.bold()).foregroundColor(.secondary)
                    Spacer()
                    Button(action: openAddSetAlert) { Image(systemName: "plus").font(.caption.bold()) }
                        .buttonStyle(.plain).foregroundColor(.accentColor)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(appState.ruleSets) { ruleSet in
                            HStack {
                                Text(ruleSet.name)
                                    .font(.subheadline)
                                    .fontWeight(selectedSetId == ruleSet.id ? .bold : .regular)
                                    .foregroundColor(selectedSetId == ruleSet.id ? .primary : .secondary)
                                Spacer()
                                if Self.shouldShowDeleteSetButton(ruleSetCount: appState.ruleSets.count, isBlocking: appState.isBlocking) {
                                    Button(action: deleteSetAction(ruleSet)) {
                                        Image(systemName: "minus.circle.fill").font(.caption).foregroundColor(.red.opacity(0.4))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(selectedSetId == ruleSet.id ? Color.primary.opacity(0.08) : Color.clear)
                            .cornerRadius(6).padding(.horizontal, 8)
                            .onTapGesture(perform: selectSetTapAction(ruleSet))
                        }
                    }
                }
            }
            Spacer()
        }
        .frame(width: Self.sidebarWidth(isSidebarVisible: isSidebarVisible))
        .background(Self.sidebarBackgroundColor(colorScheme: colorScheme))
        .clipped()
        if Self.shouldShowSidebarDivider(isSidebarVisible: isSidebarVisible) { Divider() }
    }

    @ViewBuilder
    private var mainContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: toggleSidebar) {
                    Image(systemName: Self.sidebarToggleIcon(isSidebarVisible: isSidebarVisible))
                        .font(.system(size: 14, weight: .bold)).foregroundColor(.secondary)
                        .frame(width: 24, height: 24).background(Color.primary.opacity(0.05)).clipShape(Circle())
                }
                .buttonStyle(.plain).padding(.leading, 12)
                if let set = selectedSet {
                    Text(set.name).font(.headline).padding(.leading, 8)
                }
                Spacer()
            }
            .frame(height: 44).background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            Divider()

            if let selectedSet {
                List {
                    Section(header: Text("Allowed in this list")) {
                        ForEach(selectedSet.urls, id: \.self) { rule in
                            URLListRow(url: rule, onDelete: removeRuleAction(rule: rule, setId: selectedSet.id))
                        }
                    }
                    Section(header: suggestionsHeader) {
                        if Self.shouldShowSuggestionsList(isSuggestionsExpanded: isSuggestionsExpanded) { suggestionsList(for: selectedSet) }
                    }
                }
                .listStyle(.plain)
                Divider()
                addRuleFooter(for: selectedSet)
            } else {
                Text("Select a list to edit").foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var suggestionsHeader: some View {
        HStack {
            Button(action: toggleSuggestions) {
                HStack(spacing: 4) {
                    Image(systemName: Self.suggestionsChevronIcon(isSuggestionsExpanded: isSuggestionsExpanded)).font(.caption2.bold())
                    Text("Open Tabs Suggestions")
                }
            }
            .buttonStyle(.plain)
            Spacer()
            if Self.shouldShowRefreshSuggestionsButton(isSuggestionsExpanded: isSuggestionsExpanded) {
                Button(action: refreshSuggestions) { Image(systemName: "arrow.clockwise").font(.caption) }.buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func suggestionsList(for selectedSet: RuleSet) -> some View {
        let filtered = filteredSuggestions(for: selectedSet)
        if filtered.isEmpty {
            Text(Self.suggestionsEmptyText(currentOpenUrls: appState.currentOpenUrls))
                .font(.caption).foregroundColor(.secondary)
        } else {
            ForEach(filtered, id: \.self) { url in
                HStack {
                    Image(systemName: "plus.circle").foregroundColor(.green)
                    Text(url).font(.system(.caption, design: .monospaced)).lineLimit(1)
                    Spacer()
                    Button("Add", action: addSuggestionAction(url: url, setId: selectedSet.id)).buttonStyle(.bordered).controlSize(.small)
                }
            }
        }
    }

    static func filterSuggestions(_ urls: [String], existing: RuleSet) -> [String] {
        urls.filter { !existing.containsRule($0) }
    }

    private func addRuleFooter(for selectedSet: RuleSet) -> some View {
        HStack(spacing: 12) {
            TextField("Add URL to allow...", text: $newRule, onCommit: addRuleAction(to: selectedSet))
                .textFieldStyle(.plain).padding(8).background(Color.primary.opacity(0.05)).cornerRadius(6)
            Button(action: addRuleAction(to: selectedSet)) {
                Image(systemName: "plus").font(.headline).frame(width: 24, height: 24)
            }
            .disabled(newRule.isEmpty).buttonStyle(.borderedProminent)
        }
        .padding(16)
    }

    var selectedSet: RuleSet? {
        appState.ruleSets.first(where: { $0.id == selectedSetId })
    }

    func handleOnAppear() {
        if selectedSetId == nil { selectedSetId = appState.currentPrimaryRuleSetId }
        appState.refreshCurrentOpenUrls()
    }

    func openAddSetAlert() {
        showAddSetAlert = true
    }

    func createSet() {
        let newSet = RuleSet(name: newSetName, urls: [])
        appState.ruleSets.append(newSet)
        selectedSetId = newSet.id
        newSetName = ""
    }

    func cancelCreateSet() {
        newSetName = ""
    }

    func toggleSidebar() {
        withAnimation(.spring()) { isSidebarVisible.toggle() }
    }

    func toggleSuggestions() {
        withAnimation { isSuggestionsExpanded.toggle() }
    }

    func refreshSuggestions() {
        appState.refreshCurrentOpenUrls()
    }

    func addSuggestion(url: String, setId: UUID) {
        appState.addSpecificRule(url, to: setId)
    }

    func addSuggestionAction(url: String, setId: UUID) -> () -> Void {
        { addSuggestion(url: url, setId: setId) }
    }

    func deleteSetAction(_ ruleSet: RuleSet) -> () -> Void {
        { deleteSet(ruleSet) }
    }

    func selectSetTapAction(_ ruleSet: RuleSet) -> () -> Void {
        { if !appState.isBlocking { selectedSetId = ruleSet.id } }
    }

    func removeRuleAction(rule: String, setId: UUID) -> () -> Void {
        { appState.removeRule(rule, from: setId) }
    }

    func filteredSuggestions(for selectedSet: RuleSet) -> [String] {
        RulesView.filterSuggestions(appState.currentOpenUrls, existing: selectedSet)
    }

    func addRuleAction(to ruleSet: RuleSet) -> () -> Void {
        { addRule(to: ruleSet) }
    }

    static func shouldShowDeleteSetButton(ruleSetCount: Int, isBlocking: Bool) -> Bool {
        ruleSetCount > 1 && !isBlocking
    }

    static func sidebarWidth(isSidebarVisible: Bool) -> CGFloat {
        isSidebarVisible ? 200 : 0
    }

    static func sidebarBackgroundColor(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(NSColor.windowBackgroundColor) : Color.primary.opacity(0.03)
    }

    static func shouldShowSidebarDivider(isSidebarVisible: Bool) -> Bool {
        isSidebarVisible
    }

    static func sidebarToggleIcon(isSidebarVisible: Bool) -> String {
        isSidebarVisible ? "chevron.left" : "chevron.right"
    }

    static func shouldShowSuggestionsList(isSuggestionsExpanded: Bool) -> Bool {
        isSuggestionsExpanded
    }

    static func shouldShowRefreshSuggestionsButton(isSuggestionsExpanded: Bool) -> Bool {
        isSuggestionsExpanded
    }

    static func suggestionsChevronIcon(isSuggestionsExpanded: Bool) -> String {
        isSuggestionsExpanded ? "chevron.down" : "chevron.right"
    }

    static func suggestionsEmptyText(currentOpenUrls: [String]) -> String {
        currentOpenUrls.isEmpty ? "No open tabs detected." : "All open tabs are already allowed."
    }

    func addRule(to ruleSet: RuleSet) {
        appState.addRule(newRule, to: ruleSet.id)
        newRule = ""
    }

    func deleteSet(_ ruleSet: RuleSet) {
        appState.deleteSet(id: ruleSet.id)
        if selectedSetId == ruleSet.id { selectedSetId = appState.ruleSets.first?.id }
    }
}
