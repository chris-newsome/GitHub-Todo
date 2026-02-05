import Foundation

struct GitHubUser: Codable, Identifiable, Hashable {
    let id: Int
    let login: String
    let avatar_url: URL?
}

struct GitHubRepo: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let full_name: String
    let owner: GitHubUser
    let privateRepo: Bool
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, name, full_name, owner, description
        case privateRepo = "private"
    }
}

struct GitHubLabel: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let color: String
}

struct GitHubMilestone: Codable, Identifiable, Hashable {
    let id: Int
    let number: Int
    let title: String
    let state: String
}

struct GitHubIssue: Codable, Identifiable, Hashable {
    let id: Int
    let number: Int
    var title: String
    var body: String?
    var state: String
    var assignees: [GitHubUser]
    var labels: [GitHubLabel]
    var milestone: GitHubMilestone?
    let user: GitHubUser?
    let pull_request: GitHubPullRequestRef?

    var displayBody: String {
        let parsed = IssueBodyMetadata.parse(body: body)
        return parsed.cleanBody
    }
}

struct GitHubPullRequestRef: Codable, Hashable {
    let url: URL?
    let html_url: URL?
}

struct GitHubIssueSummary: Codable, Identifiable, Hashable {
    let id: Int
    let number: Int
    let title: String
    let html_url: URL?
}


struct IssueCreateRequest: Encodable {
    let title: String
    let body: String?
    let assignees: [String]?
    let labels: [String]?
    let milestone: Int?
}

struct IssueUpdateRequest: Encodable {
    let title: String
    let body: String?
    let state: String
    let assignees: [String]
    let labels: [String]
    let milestone: Int?
}
