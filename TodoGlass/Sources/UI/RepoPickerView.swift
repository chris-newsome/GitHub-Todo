import SwiftUI

struct RepoPickerView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""

    private var filteredRepos: [GitHubRepo] {
        if searchText.trimmed.isEmpty { return appState.repos }
        return appState.repos.filter { repo in
            repo.full_name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pick a repository")
                            .font(.system(.headline, design: .rounded))
                        Text("Todos are stored as GitHub issues in the repo you choose.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)

                List {
                    ForEach(filteredRepos) { repo in
                        Button {
                            appState.selectRepo(repo)
                            Task { await appState.refreshIssues() }
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(repo.name)
                                        .font(.system(.headline, design: .rounded))
                                    Text(repo.full_name)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if repo.privateRepo {
                                    GlassPill(text: "Private")
                                } else {
                                    GlassPill(text: "Public")
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Repositories")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out") { appState.signOut() }
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .task {
            if appState.repos.isEmpty {
                await appState.loadRepos()
            }
        }
    }
}
