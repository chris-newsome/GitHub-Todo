import SwiftUI

struct MyTodosView: View {
    @EnvironmentObject var appState: AppState
    @State private var showClosed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    VStack(spacing: 12) {
                        ForEach(appState.myIssues) { issue in
                            NavigationLink {
                                IssueDetailView(issue: issue)
                            } label: {
                                IssueRow(issue: issue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("My Todos")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    RepoSwitcherMenu()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(showClosed ? "Open" : "Closed") {
                        showClosed.toggle()
                        Task { await appState.refreshIssues(state: showClosed ? "closed" : "open") }
                    }
                }
            }
            .task {
                if appState.myIssues.isEmpty {
                    await appState.refreshIssues()
                }
            }
        }
    }

    private var header: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Assigned to you")
                    .font(.system(.headline, design: .rounded))
                Text("Keep focus on issues currently in your lane.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
    }
}
