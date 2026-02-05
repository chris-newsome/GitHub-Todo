import SwiftUI

struct IssueRow: View {
    let issue: GitHubIssue

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(issue.title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("#\(issue.number)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                if !issue.displayBody.isEmpty {
                    Text(issue.displayBody)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    if issue.state == "closed" {
                        GlassPill(text: "Closed")
                    } else {
                        GlassPill(text: "Open")
                    }
                    if let dueDate = IssueBodyMetadata.parse(body: issue.body).dueDate {
                        GlassPill(text: "Due \(IssueBodyMetadata.displayString(for: dueDate))")
                    }
                    if let milestone = issue.milestone {
                        GlassPill(text: milestone.title)
                    }
                    ForEach(issue.labels.prefix(2)) { label in
                        GlassPill(text: label.name)
                    }
                }
            }
        }
    }
}
