import SwiftUI

struct WidgetCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
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

struct PillMenuLabel: View {
    let text: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption.bold())
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct URLListRow: View {
    let url: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "link")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 2)
            
            Text(url)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 6)
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    let color: Color
    var maxWidth: CGFloat? = nil
    var isProminent: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 30)
            .padding(.vertical, 8)
            .frame(maxWidth: maxWidth)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isProminent ? color : color.opacity(configuration.isPressed ? 0.15 : 0.08))
            )
            .foregroundColor(isProminent ? .white : color)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(isProminent ? 0 : 0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
