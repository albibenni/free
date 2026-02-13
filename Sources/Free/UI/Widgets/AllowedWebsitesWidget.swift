import SwiftUI

struct AllowedWebsitesWidget: View {
    @EnvironmentObject var appState: AppState
    @Binding var showRules: Bool
    @State private var isExpanded = false

    var body: some View {
        WidgetCard {
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
                                Button("Manage Lists...") { showRules = true }
                            } label: {
                                PillMenuLabel(
                                    text: appState.ruleSets.first(where: { $0.id == appState.activeRuleSetId })?.name ?? "Default",
                                    icon: "link",
                                    color: .blue
                                )
                            }
                            .menuStyle(.borderlessButton)
                            .disabled(appState.isBlocking)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("PREVIEW")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        URLPreviewList(appState.allowedRules)
                    }

                    Button(action: { showRules = true }) {
                        Text("Manage & Edit Lists")
                            .font(.headline)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(FocusColor.color(for: appState.accentColorIndex))
                }
                .padding([.horizontal, .bottom])
            } else if let activeSet = appState.ruleSets.first(where: { $0.id == appState.activeRuleSetId }) {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.caption2)
                    Text(activeSet.name)
                        .font(.caption.bold())
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }
}
