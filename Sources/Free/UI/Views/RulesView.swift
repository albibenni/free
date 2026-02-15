import SwiftUI

struct RulesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedSetId: UUID?
    @State private var newRule: String = ""
    @State private var showAddSetAlert = false
    @State private var newSetName = ""
    @State private var isSidebarVisible = true
    @State private var isSuggestionsExpanded = false

    var body: some View {
        HStack(spacing: 0) {
            sidebarView
            mainContentView
        }
        .frame(minWidth: 700, minHeight: 600)
        .onAppear {
            if selectedSetId == nil { selectedSetId = appState.currentPrimaryRuleSetId }
            appState.refreshCurrentOpenUrls()
        }
        .alert("New Allowed List", isPresented: $showAddSetAlert) {
            TextField("List Name", text: $newSetName)
            Button("Create") {
                let newSet = RuleSet(name: newSetName, urls: [])
                appState.ruleSets.append(newSet)
                selectedSetId = newSet.id
                newSetName = ""
            }
            Button("Cancel", role: .cancel) { newSetName = "" }
        }
    }

    @ViewBuilder
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isSidebarVisible {
                HStack {
                    Text("ALLOWED LISTS").font(.caption.bold()).foregroundColor(.secondary)
                    Spacer()
                    Button(action: { showAddSetAlert = true }) { Image(systemName: "plus").font(.caption.bold()) }
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
                                if appState.ruleSets.count > 1 && !appState.isBlocking {
                                    Button(action: { deleteSet(ruleSet) }) {
                                        Image(systemName: "minus.circle.fill").font(.caption).foregroundColor(.red.opacity(0.4))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(selectedSetId == ruleSet.id ? Color.primary.opacity(0.08) : Color.clear)
                            .cornerRadius(6).padding(.horizontal, 8)
                            .onTapGesture { if !appState.isBlocking { selectedSetId = ruleSet.id } }
                        }
                    }
                }
            }
            Spacer()
        }
        .frame(width: isSidebarVisible ? 200 : 0)
        .background(colorScheme == .dark ? Color(NSColor.windowBackgroundColor) : Color.primary.opacity(0.03))
        .clipped()
        if isSidebarVisible { Divider() }
    }

    @ViewBuilder
    private var mainContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: { withAnimation(.spring()) { isSidebarVisible.toggle() } }) {
                    Image(systemName: isSidebarVisible ? "chevron.left" : "chevron.right")
                        .font(.system(size: 14, weight: .bold)).foregroundColor(.secondary)
                        .frame(width: 24, height: 24).background(Color.primary.opacity(0.05)).clipShape(Circle())
                }
                .buttonStyle(.plain).padding(.leading, 12)
                if let set = appState.ruleSets.first(where: { $0.id == selectedSetId }) {
                    Text(set.name).font(.headline).padding(.leading, 8)
                }
                Spacer()
            }
            .frame(height: 44).background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            Divider()

            if let selectedSet = appState.ruleSets.first(where: { $0.id == selectedSetId }) {
                List {
                    Section(header: Text("Allowed in this list")) {
                        ForEach(selectedSet.urls, id: \.self) { rule in
                            URLListRow(url: rule, onDelete: { appState.removeRule(rule, from: selectedSet.id) })
                        }
                    }
                    Section(header: suggestionsHeader) {
                        if isSuggestionsExpanded { suggestionsList(for: selectedSet) }
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
            Button(action: { withAnimation { isSuggestionsExpanded.toggle() } }) {
                HStack(spacing: 4) {
                    Image(systemName: isSuggestionsExpanded ? "chevron.down" : "chevron.right").font(.caption2.bold())
                    Text("Open Tabs Suggestions")
                }
            }
            .buttonStyle(.plain)
            Spacer()
            if isSuggestionsExpanded {
                Button(action: { appState.refreshCurrentOpenUrls() }) { Image(systemName: "arrow.clockwise").font(.caption) }.buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func suggestionsList(for selectedSet: RuleSet) -> some View {
        if appState.currentOpenUrls.isEmpty {
            Text("No open tabs detected.").font(.caption).foregroundColor(.secondary)
        } else {
            let filtered = appState.currentOpenUrls.filter { !selectedSet.urls.contains($0) }
            if filtered.isEmpty {
                Text("All open tabs are already allowed.").font(.caption).foregroundColor(.secondary)
            } else {
                ForEach(filtered, id: \.self) { url in
                    HStack {
                        Image(systemName: "plus.circle").foregroundColor(.green)
                        Text(url).font(.system(.caption, design: .monospaced)).lineLimit(1)
                        Spacer()
                        Button("Add") { appState.addSpecificRule(url, to: selectedSet.id) }.buttonStyle(.bordered).controlSize(.small)
                    }
                }
            }
        }
    }

    private func addRuleFooter(for selectedSet: RuleSet) -> some View {
        HStack(spacing: 12) {
            TextField("Add URL to allow...", text: $newRule, onCommit: { addRule(to: selectedSet) })
                .textFieldStyle(.plain).padding(8).background(Color.primary.opacity(0.05)).cornerRadius(6)
            Button(action: { addRule(to: selectedSet) }) {
                Image(systemName: "plus").font(.headline).frame(width: 24, height: 24)
            }
            .disabled(newRule.isEmpty).buttonStyle(.borderedProminent)
        }
        .padding(16)
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
