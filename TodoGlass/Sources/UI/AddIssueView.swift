import SwiftUI

struct AddIssueView: View {
    @EnvironmentObject var appState: AppState
    @State private var title = ""
    @State private var bodyText = ""
    @State private var dueDate: Date = Date()
    @State private var useDueDate = false
    @State private var createdIssue: GitHubIssue?
    @State private var showCreated = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("New Todo")
                                .font(.system(.headline, design: .rounded))
                            TextField("Title", text: $title)
                                .textInputAutocapitalization(.sentences)
                                .submitLabel(.done)
                                .padding(12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            TextEditor(text: $bodyText)
                                .frame(height: 160)
                                .padding(8)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            Toggle("Add due date", isOn: $useDueDate)
                                .font(.system(.subheadline, design: .rounded))
                            if useDueDate {
                                DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Button {
                        Task {
                            let composedBody = IssueBodyMetadata.apply(
                                dueDate: useDueDate ? dueDate : nil,
                                to: bodyText.trimmed
                            )
                            let issue = await appState.createIssue(
                                title: title.trimmed,
                                body: composedBody.trimmed.isEmpty ? nil : composedBody
                            )
                            if let issue {
                                createdIssue = issue
                                title = ""
                                bodyText = ""
                                useDueDate = false
                                showCreated = true
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Create Todo")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GlassButtonStyle())
                    .disabled(title.trimmed.isEmpty)
                    .padding(.horizontal, 20)

                    if let repo = appState.selectedRepo {
                        Text("Issues are created in \(repo.full_name)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("Add")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    RepoSwitcherMenu()
                }
            }
            .navigationDestination(isPresented: $showCreated) {
                if let issue = createdIssue {
                    IssueDetailView(issue: issue)
                }
            }
        }
    }
}
