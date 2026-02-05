import SwiftUI

struct IssueDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var bodyText: String
    @State private var state: String
    @State private var assignees: [GitHubUser]
    @State private var labels: [GitHubLabel]
    @State private var milestone: GitHubMilestone?
    @State private var dueDate: Date = Date()
    @State private var useDueDate = false

    @State private var availableAssignees: [GitHubUser] = []
    @State private var availableLabels: [GitHubLabel] = []
    @State private var availableMilestones: [GitHubMilestone] = []
    @State private var blockedBy: [GitHubIssueSummary] = []
    @State private var parentIssue: GitHubIssueSummary?
    @State private var subIssues: [GitHubIssueSummary] = []
    @State private var blockedByInput = ""
    @State private var parentInput = ""
    @State private var subIssueInput = ""

    @State private var isSaving = false
    @State private var autosaveTask: Task<Void, Never>?
    @State private var lastSavedFingerprint = ""
    @State private var saveStatus: String = ""

    let issue: GitHubIssue

    init(issue: GitHubIssue) {
        self.issue = issue
        let parsed = IssueBodyMetadata.parse(body: issue.body)
        _title = State(initialValue: issue.title)
        _bodyText = State(initialValue: parsed.cleanBody)
        _state = State(initialValue: issue.state)
        _assignees = State(initialValue: issue.assignees)
        _labels = State(initialValue: issue.labels)
        _milestone = State(initialValue: issue.milestone)
        _useDueDate = State(initialValue: parsed.dueDate != nil)
        if let due = parsed.dueDate {
            _dueDate = State(initialValue: due)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Issue Details")
                            .font(.system(.headline, design: .rounded))
                        TextField("Title", text: $title)
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

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Status")
                            .font(.system(.headline, design: .rounded))
                        Picker("Status", selection: $state) {
                            Text("Open").tag("open")
                            Text("Closed").tag("closed")
                        }
                        .pickerStyle(.segmented)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Assignees")
                            .font(.system(.headline, design: .rounded))
                        if availableAssignees.isEmpty {
                            Text("No assignees available.")
                                .foregroundStyle(.secondary)
                        } else {
                            WrapList(items: availableAssignees) { user in
                                assignees.contains(user)
                            } toggle: { user in
                                if let index = assignees.firstIndex(of: user) {
                                    assignees.remove(at: index)
                                } else {
                                    assignees.append(user)
                                }
                            } label: { user, isSelected in
                                HStack(spacing: 6) {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isSelected ? .primary : .secondary)
                                    Text(user.login)
                                        .font(.system(.caption, design: .rounded))
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(isSelected ? Color.white.opacity(0.35) : Color.white.opacity(0.15), in: Capsule())
                                .overlay(
                                    Capsule().stroke(Color.white.opacity(isSelected ? 0.7 : 0.3), lineWidth: 1)
                                )
                                .contentShape(Capsule())
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Labels")
                            .font(.system(.headline, design: .rounded))
                        if availableLabels.isEmpty {
                            Text("No labels yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            WrapList(items: availableLabels) { label in
                                labels.contains(label)
                            } toggle: { label in
                                if let index = labels.firstIndex(of: label) {
                                    labels.remove(at: index)
                                } else {
                                    labels.append(label)
                                }
                            } label: { label, isSelected in
                                Text(label.name)
                                    .font(.system(.caption, design: .rounded))
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(Color(hex: label.color).opacity(isSelected ? 0.35 : 0.2), in: Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color(hex: label.color).opacity(isSelected ? 0.9 : 0.5), lineWidth: 1)
                                            .allowsHitTesting(false)
                                    )
                                    .contentShape(Capsule())
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Milestone")
                            .font(.system(.headline, design: .rounded))
                        Picker("Milestone", selection: Binding(
                            get: { milestone?.number ?? 0 },
                            set: { selection in
                                milestone = availableMilestones.first(where: { $0.number == selection })
                            }
                        )) {
                            Text("None").tag(0)
                            ForEach(availableMilestones) { milestone in
                                Text(milestone.title).tag(milestone.number)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Blocked By")
                            .font(.system(.headline, design: .rounded))
                        RelationshipList(items: blockedBy, onRemove: { issue in
                            Task { await removeBlockedBy(issue) }
                        })

                        HStack(spacing: 8) {
                            TextField("Issue #", text: $blockedByInput)
                                .keyboardType(.numberPad)
                                .padding(10)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            Button("Add") {
                                Task { await addBlockedBy() }
                            }
                            .buttonStyle(GlassButtonStyle())
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Parent")
                            .font(.system(.headline, design: .rounded))
                        if let parentIssue {
                            RelationshipRow(issue: parentIssue, showRemove: true) {
                                Task { await clearParent() }
                            }
                        } else {
                            Text("No parent issue.")
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 8) {
                            TextField("Parent issue #", text: $parentInput)
                                .keyboardType(.numberPad)
                                .padding(10)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            Button("Set") {
                                Task { await setParent() }
                            }
                            .buttonStyle(GlassButtonStyle())
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Child Issues")
                            .font(.system(.headline, design: .rounded))
                        RelationshipList(items: subIssues, onRemove: { issue in
                            Task { await removeSubIssue(issue) }
                        })
                        HStack(spacing: 8) {
                            TextField("Child issue #", text: $subIssueInput)
                                .keyboardType(.numberPad)
                                .padding(10)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            Button("Add") {
                                Task { await addSubIssue() }
                            }
                            .buttonStyle(GlassButtonStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 180)
        }
        .navigationTitle("Issue #\(issue.number)")
        .scrollDismissesKeyboard(.interactively)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isSaving {
                    HStack(spacing: 6) {
                        ProgressView()
                        Text("Saving…")
                    }
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                } else if !saveStatus.isEmpty {
                    Text(saveStatus)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            await loadOptions()
            lastSavedFingerprint = fingerprint()
            await loadRelationships()
        }
        .onChange(of: title) { _ in scheduleAutosave() }
        .onChange(of: bodyText) { _ in scheduleAutosave() }
        .onChange(of: state) { _ in scheduleAutosave() }
        .onChange(of: assignees) { _ in scheduleAutosave() }
        .onChange(of: labels) { _ in scheduleAutosave() }
        .onChange(of: milestone?.number ?? 0) { _ in scheduleAutosave() }
        .onChange(of: useDueDate) { _ in scheduleAutosave() }
        .onChange(of: dueDate) { _ in scheduleAutosave() }
    }

    private func loadOptions() async {
        guard let api = appState.apiClient(), let repo = appState.selectedRepo else { return }
        do {
            async let assignees = api.fetchAssignees(owner: repo.owner.login, repo: repo.name)
            async let labels = api.fetchLabels(owner: repo.owner.login, repo: repo.name)
            async let milestones = api.fetchMilestones(owner: repo.owner.login, repo: repo.name)
            self.availableAssignees = try await assignees
            self.availableLabels = try await labels
            self.availableMilestones = try await milestones
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func loadRelationships() async {
        guard let api = appState.apiClient(), let repo = appState.selectedRepo else { return }
        do {
            async let blockedBy = api.fetchBlockedBy(owner: repo.owner.login, repo: repo.name, number: issue.number)
            async let parent = api.fetchParentIssue(owner: repo.owner.login, repo: repo.name, number: issue.number)
            async let subIssues = api.fetchSubIssues(owner: repo.owner.login, repo: repo.name, number: issue.number)
            self.blockedBy = try await blockedBy
            self.parentIssue = try await parent
            self.subIssues = try await subIssues
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func addBlockedBy() async {
        guard let api = appState.apiClient(), let repo = appState.selectedRepo else { return }
        guard let number = Int(blockedByInput.trimmed) else { return }
        do {
            let target = try await api.fetchIssue(owner: repo.owner.login, repo: repo.name, number: number)
            try await api.addBlockedBy(owner: repo.owner.login, repo: repo.name, number: issue.number, blockedByIssueId: target.id)
            blockedByInput = ""
            await loadRelationships()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func removeBlockedBy(_ target: GitHubIssueSummary) async {
        guard let api = appState.apiClient(), let repo = appState.selectedRepo else { return }
        do {
            try await api.removeBlockedBy(owner: repo.owner.login, repo: repo.name, number: issue.number, blockedByIssueId: target.id)
            await loadRelationships()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func setParent() async {
        guard let api = appState.apiClient(), let repo = appState.selectedRepo else { return }
        guard let number = Int(parentInput.trimmed) else { return }
        do {
            let parent = try await api.fetchIssue(owner: repo.owner.login, repo: repo.name, number: number)
            try await api.addSubIssue(owner: repo.owner.login, repo: repo.name, parentNumber: number, subIssueId: issue.id)
            parentInput = ""
            await loadRelationships()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func clearParent() async {
        guard let api = appState.apiClient(), let repo = appState.selectedRepo, let parent = parentIssue else { return }
        do {
            try await api.removeSubIssue(owner: repo.owner.login, repo: repo.name, parentNumber: parent.number, subIssueId: issue.id)
            await loadRelationships()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func addSubIssue() async {
        guard let api = appState.apiClient(), let repo = appState.selectedRepo else { return }
        guard let number = Int(subIssueInput.trimmed) else { return }
        do {
            let child = try await api.fetchIssue(owner: repo.owner.login, repo: repo.name, number: number)
            try await api.addSubIssue(owner: repo.owner.login, repo: repo.name, parentNumber: issue.number, subIssueId: child.id)
            subIssueInput = ""
            await loadRelationships()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func removeSubIssue(_ child: GitHubIssueSummary) async {
        guard let api = appState.apiClient(), let repo = appState.selectedRepo else { return }
        do {
            try await api.removeSubIssue(owner: repo.owner.login, repo: repo.name, parentNumber: issue.number, subIssueId: child.id)
            await loadRelationships()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func saveChanges() async {
        guard let api = appState.apiClient(), let repo = appState.selectedRepo else { return }
        isSaving = true
        saveStatus = ""
        defer { isSaving = false }
        do {
            let composedBody = IssueBodyMetadata.apply(
                dueDate: useDueDate ? dueDate : nil,
                to: bodyText.trimmed
            )
            let request = IssueUpdateRequest(
                title: title.trimmed,
                body: composedBody.trimmed.isEmpty ? nil : composedBody,
                state: state,
                assignees: assignees.map { $0.login },
                labels: labels.map { $0.name },
                milestone: milestone?.number
            )
            _ = try await api.updateIssue(owner: repo.owner.login, repo: repo.name, number: issue.number, requestBody: request)
            await appState.refreshIssues()
            lastSavedFingerprint = fingerprint()
            saveStatus = "Saved"
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                if saveStatus == "Saved" { saveStatus = "" }
            }
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            let current = fingerprint()
            guard current != lastSavedFingerprint else { return }
            await saveChanges()
        }
    }

    private func fingerprint() -> String {
        let composedBody = IssueBodyMetadata.apply(
            dueDate: useDueDate ? dueDate : nil,
            to: bodyText.trimmed
        )
        let parts: [String] = [
            title.trimmed,
            composedBody,
            state,
            assignees.map { $0.login }.sorted().joined(separator: ","),
            labels.map { $0.name }.sorted().joined(separator: ","),
            milestone?.number.description ?? "0"
        ]
        return parts.joined(separator: "|")
    }
}

struct WrapList<Item: Identifiable & Hashable, Chip: View>: View {
    let items: [Item]
    let isSelected: (Item) -> Bool
    let toggle: (Item) -> Void
    let label: (Item, Bool) -> Chip

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items) { item in
                Button {
                    toggle(item)
                } label: {
                    label(item, isSelected(item))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? UIScreen.main.bounds.width
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

}

struct RelationshipRow: View {
    let issue: GitHubIssueSummary
    let showRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("#\(issue.number) \(issue.title)")
                    .font(.system(.subheadline, design: .rounded))
                if let url = issue.html_url {
                    Text(url.absoluteString)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if showRemove {
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                }
            }
        }
        .padding(.vertical, 6)
    }
}

struct RelationshipList: View {
    let items: [GitHubIssueSummary]
    let onRemove: (GitHubIssueSummary) -> Void

    var body: some View {
        if items.isEmpty {
            Text("None yet.")
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 8) {
                ForEach(items) { item in
                    RelationshipRow(issue: item, showRemove: true) {
                        onRemove(item)
                    }
                    Divider().opacity(0.3)
                }
            }
        }
    }
}
