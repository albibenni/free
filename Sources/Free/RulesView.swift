import SwiftUI

struct RulesView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedSetId: UUID?
    @State private var newRule: String = ""
    @State private var showAddSetAlert = false
    @State private var newSetName = ""
    @State private var isSidebarVisible = true

    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar: List of RuleSets
            VStack(alignment: .leading, spacing: 0) {
                if isSidebarVisible {
                    HStack {
                        Text("ALLOWED LISTS")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: { showAddSetAlert = true }) {
                            Image(systemName: "plus")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(appState.ruleSets) { ruleSet in
                                HStack {
                                    Text(ruleSet.name)
                                        .font(.subheadline)
                                        .fontWeight(selectedSetId == ruleSet.id ? .bold : .regular)
                                        .foregroundColor(selectedSetId == ruleSet.id ? .primary : .secondary)
                                        .opacity(selectedSetId == ruleSet.id ? 1.0 : 0.6)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    if appState.ruleSets.count > 1 && !appState.isBlocking {
                                        Button(action: { deleteSet(ruleSet) }) {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.red.opacity(0.4))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedSetId == ruleSet.id ? Color.primary.opacity(0.08) : Color.clear)
                                .cornerRadius(6)
                                .padding(.horizontal, 8)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if !appState.isBlocking {
                                        selectedSetId = ruleSet.id
                                    }
                                }
                            }
                        }
                    }
                }
                Spacer()
            }
            .frame(width: isSidebarVisible ? 200 : 0)
            .background(Color(NSColor.windowBackgroundColor).brightness(-0.03))
            .clipped()
            
            if isSidebarVisible {
                Divider()
            }

            // Right Content: URLs in selected RuleSet
            VStack(alignment: .leading, spacing: 0) {
                // Header with Chevron Toggle
                HStack {
                    Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isSidebarVisible.toggle() } }) {
                        Image(systemName: isSidebarVisible ? "chevron.left" : "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 12)

                    if let selectedSet = appState.ruleSets.first(where: { $0.id == selectedSetId }) {
                        Text(selectedSet.name)
                            .font(.headline)
                            .padding(.leading, 8)
                    }
                    
                    Spacer()
                }
                .frame(height: 44)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                
                Divider()

                if let selectedSet = appState.ruleSets.first(where: { $0.id == selectedSetId }) {
                    VStack(alignment: .leading, spacing: 0) {
                        List {
                            ForEach(selectedSet.urls, id: \.self) { rule in
                                HStack(alignment: .top) {
                                    Image(systemName: "link")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 2)
                                    
                                    Text(rule)
                                        .font(.system(.subheadline, design: .monospaced))
                                        .foregroundColor(.primary.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        removeRule(rule, from: selectedSet)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red.opacity(0.6))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        .listStyle(PlainListStyle())

                        Divider()

                        HStack(spacing: 12) {
                            TextField("Add URL to allow...", text: $newRule, onCommit: { addRule(to: selectedSet) })
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(6)
                            
                            Button(action: { addRule(to: selectedSet) }) {
                                Image(systemName: "plus")
                                    .font(.headline)
                                    .frame(width: 24, height: 24)
                            }
                            .disabled(newRule.isEmpty)
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(16)
                    }
                } else {
                    VStack {
                        Text("Select a list to edit")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 700, minHeight: 600)
        .onAppear {
            if selectedSetId == nil {
                selectedSetId = appState.currentPrimaryRuleSetId
            }
        }
        .alert("New Allowed List", isPresented: $showAddSetAlert) {
            TextField("List Name", text: $newSetName)
            Button("Create") {
                let newSet = RuleSet(name: newSetName, urls: [])
                appState.ruleSets.append(newSet)
                selectedSetId = newSet.id
                newSetName = ""
            }
            Button("Cancel", role: .cancel) {
                newSetName = ""
            }
        }
    }

    func addRule(to ruleSet: RuleSet) {
        let cleanedRule = newRule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedRule.isEmpty else { return }

        if let index = appState.ruleSets.firstIndex(where: { $0.id == ruleSet.id }) {
            if !appState.ruleSets[index].urls.contains(cleanedRule) {
                appState.ruleSets[index].urls.append(cleanedRule)
            }
        }

        newRule = ""
    }

    func removeRule(_ rule: String, from ruleSet: RuleSet) {
        if let index = appState.ruleSets.firstIndex(where: { $0.id == ruleSet.id }) {
            if let ruleIndex = appState.ruleSets[index].urls.firstIndex(of: rule) {
                appState.ruleSets[index].urls.remove(at: ruleIndex)
            }
        }
    }

    func deleteSet(_ ruleSet: RuleSet) {
        appState.ruleSets.removeAll(where: { $0.id == ruleSet.id })
        if selectedSetId == ruleSet.id {
            selectedSetId = appState.ruleSets.first?.id
        }
    }
}