import SwiftUI

struct SheetWrapper<Content: View>: View {
    let title: String
    @Binding var isPresented: Bool
    let content: Content

    init(title: String, isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.title = title
        self._isPresented = isPresented
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            content
        }
    }
}
