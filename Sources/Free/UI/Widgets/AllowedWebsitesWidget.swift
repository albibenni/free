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
                                                        Text("SELECT LIST")
                                                            .font(.caption.bold())
                                                            .foregroundColor(.secondary)
                                                        
                                                        ScrollView {
                                                            VStack(spacing: 4) {
                                                                ForEach(appState.ruleSets) { set in
                                                                    Button(action: {
                                                                        if !appState.isBlocking {
                                                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                                                appState.activeRuleSetId = set.id
                                                                            }
                                                                        }
                                                                    }) {
                                                                        HStack {
                                                                            Image(systemName: appState.activeRuleSetId == set.id ? "link.circle.fill" : "link")
                                                                                .font(.system(size: 12))
                                                                                .foregroundColor(appState.activeRuleSetId == set.id ? FocusColor.color(for: appState.accentColorIndex) : .secondary)
                                                                            
                                                                            Text(set.name)
                                                                                .font(.subheadline)
                                                                                .fontWeight(appState.activeRuleSetId == set.id ? .bold : .regular)
                                                                                .foregroundColor(appState.activeRuleSetId == set.id ? .primary : .secondary)
                                                                            
                                                                            Spacer()
                                                                            
                                                                            if appState.activeRuleSetId == set.id {
                                                                                Image(systemName: "checkmark")
                                                                                    .font(.caption.bold())
                                                                                    .foregroundColor(FocusColor.color(for: appState.accentColorIndex))
                                                                            }
                                                                        }
                                                                        .padding(.horizontal, 12)
                                                                        .padding(.vertical, 8)
                                                                        .background(appState.activeRuleSetId == set.id ? FocusColor.color(for: appState.accentColorIndex).opacity(0.1) : Color.primary.opacity(0.03))
                                                                        .cornerRadius(8)
                                                                    }
                                                                    .buttonStyle(.plain)
                                                                    .disabled(appState.isBlocking)
                                                                }
                                                            }
                                                        }
                                                        .frame(maxHeight: 200) // Limit height to keep it compact
                                                    }
                                                }
                            
                                                Divider().opacity(0.5)
                            
                                                Button(action: { showRules = true }) {                        Text("Manage & Edit Lists")
                    }
                    .buttonStyle(AppPrimaryButtonStyle(
                        color: FocusColor.color(for: appState.accentColorIndex),
                        maxWidth: .infinity
                    ))
                }
                .padding([.horizontal, .bottom])
            } else if let activeSet = appState.ruleSets.first(where: { $0.id == appState.activeRuleSetId }) {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.caption2)
                    Text(activeSet.name)
                        .font(.caption.bold())
                }
                .foregroundColor(FocusColor.color(for: appState.accentColorIndex))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }
}
