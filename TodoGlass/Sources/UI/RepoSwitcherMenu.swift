import SwiftUI

struct RepoSwitcherMenu: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Menu {
            if appState.repos.isEmpty {
                Text("No repositories")
            } else {
                ForEach(appState.repos) { repo in
                    Button {
                        appState.selectRepo(repo)
                        Task { await appState.refreshIssues() }
                    } label: {
                        Label(repo.full_name, systemImage: repo.id == appState.selectedRepo?.id ? "checkmark" : "circle")
                    }
                }
            }
            Divider()
            Button("Sign Out", role: .destructive) {
                appState.signOut()
            }
        } label: {
            HStack(spacing: 6) {
                Text(appState.selectedRepo?.name ?? "Repo")
                    .font(.system(.subheadline, design: .rounded))
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
        }
    }
}
