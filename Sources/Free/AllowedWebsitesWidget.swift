import SwiftUI

struct AllowedWebsitesWidget: View {
    @EnvironmentObject var appState: AppState
    @Binding var showRules: Bool
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "globe")
                        .font(.headline)
                        .foregroundColor(.blue)
                    Text("Allowed Websites")
                        .font(.headline)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    if !appState.ruleSets.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ACTIVE LIST")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            
                            Menu {
                                ForEach(appState.ruleSets) { set in
                                    Button(action: { appState.activeRuleSetId = set.id }) {
                                        HStack {
                                            Text(set.name)
                                            if appState.activeRuleSetId == set.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                                Divider()
                                Button("Manage Lists...") {
                                    showRules = true
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(appState.ruleSets.first(where: { $0.id == appState.activeRuleSetId })?.name ?? "Default")
                                        .font(.subheadline.bold())
                                        .lineLimit(1)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .menuStyle(.borderlessButton)
                            .disabled(appState.isBlocking)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("PREVIEW")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        if appState.allowedRules.isEmpty {
                            Text("No websites allowed in this list.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(appState.allowedRules.prefix(8), id: \.self) { rule in
                                    Text("• \(rule)")
                                        .font(.subheadline)
                                        .foregroundColor(.primary.opacity(0.8))
                                        .lineLimit(1)
                                }
                                if appState.allowedRules.count > 8 {
                                    Text("and \(appState.allowedRules.count - 8) more...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }
                        }
                    }

                    Button(action: { showRules = true }) {
                        HStack {
                            Text("Manage & Edit Lists")
                            Image(systemName: "arrow.right")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
                .padding([.horizontal, .bottom])
            } else if !appState.ruleSets.isEmpty {
                // Collapsed summary
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.caption2)
                    Text(appState.ruleSets.first(where: { $0.id == appState.activeRuleSetId })?.name ?? "Default")
                        .font(.caption.bold())
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}
