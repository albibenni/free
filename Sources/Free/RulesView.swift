import SwiftUI

struct RulesView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedSetId: UUID?
    @State private var newRule: String = ""
    @State private var showAddSetAlert = false
    @State private var newSetName = ""

    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar: List of RuleSets
            VStack(alignment: .leading, spacing: 0) {
                List {
                    Section(header: Text("Allowed Lists").font(.caption).foregroundColor(.secondary)) {
                        ForEach(appState.ruleSets) { ruleSet in
                            HStack {
                                Text(ruleSet.name)
                                    .font(.subheadline)
                                    .fontWeight(selectedSetId == ruleSet.id ? .bold : .regular)
                                    .foregroundColor(selectedSetId == ruleSet.id ? .primary : .secondary)
                                    .opacity(selectedSetId == ruleSet.id ? 1.0 : 0.4)
                                Spacer()
                                if appState.ruleSets.count > 1 && !appState.isBlocking {
                                    Button(action: { deleteSet(ruleSet) }) {
                                        Image(systemName: "minus.circle")
                                            .foregroundColor(.red.opacity(0.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !appState.isBlocking {
                                    selectedSetId = ruleSet.id
                                }
                            }
                            .listRowBackground(selectedSetId == ruleSet.id ? Color.primary.opacity(0.05) : Color.clear)
                        }
                    }
                }
                .listStyle(SidebarListStyle())
                .scrollContentBackground(.hidden)

                Divider()

                Button(action: { showAddSetAlert = true }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("New List")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                }
                .buttonStyle(.plain)
            }
            .frame(width: 180)
            .background(Color(NSColor.windowBackgroundColor).brightness(-0.02))

            Divider()

            // Right Content: URLs in selected RuleSet
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
        .frame(minWidth: 600, minHeight: 600)
        .onAppear {
            if selectedSetId == nil {
                selectedSetId = appState.ruleSets.first?.id
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

