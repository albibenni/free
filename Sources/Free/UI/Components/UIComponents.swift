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

struct URLPreviewList: View {
    let urls: [String]
    let maxVisible: Int
    
    init(_ urls: [String], maxVisible: Int = 8) {
        self.urls = urls
        self.maxVisible = maxVisible
    }
    
    var body: some View {
        if urls.isEmpty {
            Text("No websites allowed.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(urls.prefix(maxVisible), id: \.self) { rule in
                    Text("• \(rule)")
                        .font(.subheadline)
                        .foregroundColor(.primary.opacity(0.8))
                        .lineLimit(1)
                }
                if urls.count > maxVisible {
                    Text("and \(urls.count - maxVisible) more...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
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
