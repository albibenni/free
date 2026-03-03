import SwiftUI

struct SchedulesSheetHostView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isPresented: Bool

    var body: some View {
        SchedulesSheetControllerRepresentable(
            appState: appState,
            onDismiss: { isPresented = false }
        )
    }
}

private struct SchedulesSheetControllerRepresentable: NSViewControllerRepresentable {
    let appState: AppState
    let onDismiss: () -> Void

    func makeNSViewController(context: Context) -> SchedulesSheetViewController {
        SchedulesSheetViewController(
            appState: appState,
            onDismiss: onDismiss
        )
    }

    func updateNSViewController(
        _ nsViewController: SchedulesSheetViewController,
        context: Context
    ) {}
}
