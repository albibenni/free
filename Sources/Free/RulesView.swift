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
                    Section(header: Text("Allowed Lists")) {
                        ForEach(appState.ruleSets) { ruleSet in
                            HStack {
                                Text(ruleSet.name)
                                    .font(.subheadline)
                                    .fontWeight(selectedSetId == ruleSet.id ? .bold : .regular)
                                Spacer()
                                if appState.ruleSets.count > 1 {
                                    Button(action: { deleteSet(ruleSet) }) {
                                        Image(systemName: "minus.circle")
                                            .foregroundColor(.red.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSetId = ruleSet.id
                            }
                            .listRowBackground(selectedSetId == ruleSet.id ? Color.accentColor.opacity(0.1) : Color.clear)
                        }
                    }
                }
                .listStyle(SidebarListStyle())

                Divider()

                Button(action: { showAddSetAlert = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New List")
                    }
                    .padding()
                }
                .buttonStyle(.plain)
            }
            .frame(width: 180)

            Divider()

            // Right Content: URLs in selected RuleSet
            if let selectedSet = appState.ruleSets.first(where: { $0.id == selectedSetId }) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(selectedSet.name)
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.top, 12)
                    .padding(.horizontal)

                    List {
                        ForEach(selectedSet.urls, id: \.self) { rule in
                            HStack {
                                Image(systemName: "link")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(rule)
                                    .font(.subheadline)
                                Spacer()
                                Button(action: {
                                    removeRule(rule, from: selectedSet)
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

                    HStack {
                        TextField("Add URL to allow...", text: $newRule, onCommit: { addRule(to: selectedSet) })
                            .textFieldStyle(.roundedBorder)
                        
                        Button(action: { addRule(to: selectedSet) }) {
                            Image(systemName: "plus")
                        }
                        .disabled(newRule.isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            } else {
                VStack {
                    Text("Select a list to edit")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
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

