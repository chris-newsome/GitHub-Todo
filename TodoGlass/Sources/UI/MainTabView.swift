import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            MyTodosView()
                .tabItem {
                    Image(systemName: "checkmark.circle")
                    Text("My Todos")
                }

            AllIssuesView()
                .tabItem {
                    Image(systemName: "tray.full")
                    Text("All Issues")
                }

            AddIssueView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Add")
                }
        }
        .tint(.black)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            appearance.shadowColor = UIColor.black.withAlphaComponent(0.08)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
