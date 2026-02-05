import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            GlassBackground()

            if appState.token == nil {
                LoginView()
            } else if appState.selectedRepo == nil {
                RepoPickerView()
            } else {
                MainTabView()
            }
        }
        .background(WindowAccessor { window in
            appState.setPresentationAnchor(window)
        })
        .onOpenURL { url in
            appState.handleOpenURL(url)
        }
        .alert("Error", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { _ in appState.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }
}
