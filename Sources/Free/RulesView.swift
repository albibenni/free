import SwiftUI

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
