import Foundation

enum GitHubAPIError: LocalizedError {
    case missingToken
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Missing GitHub token."
        case .invalidResponse:
            return "Invalid response from GitHub."
        case .apiError(let message):
            return message
        }
    }
}

final class GitHubAPI: @unchecked Sendable {
    private let token: String

    init(token: String) {
        self.token = token
    }

    private func request(path: String, query: [URLQueryItem] = []) throws -> URLRequest {
        guard var components = URLComponents(url: AppConfig.githubAPIBase.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw GitHubAPIError.invalidResponse
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw GitHubAPIError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("TodoGlass", forHTTPHeaderField: "User-Agent")
        return request
    }


    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    func fetchCurrentUser() async throws -> GitHubUser {
        let request = try request(path: "user")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decode(GitHubUser.self, from: data)
    }

    func fetchRepos() async throws -> [GitHubRepo] {
        let request = try request(path: "user/repos", query: [
            URLQueryItem(name: "per_page", value: "100"),
            URLQueryItem(name: "sort", value: "updated"),
            URLQueryItem(name: "affiliation", value: "owner,collaborator,organization_member")
        ])
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decode([GitHubRepo].self, from: data)
    }

    func fetchIssues(owner: String, repo: String, assignee: String? = nil, state: String = "open") async throws -> [GitHubIssue] {
        var query = [
            URLQueryItem(name: "per_page", value: "100"),
            URLQueryItem(name: "state", value: state)
        ]
        if let assignee { query.append(URLQueryItem(name: "assignee", value: assignee)) }
        let request = try request(path: "repos/\(owner)/\(repo)/issues", query: query)
        let (data, _) = try await URLSession.shared.data(for: request)
        let issues = try decode([GitHubIssue].self, from: data)
        return issues.filter { $0.pull_request == nil }
    }

    func fetchIssue(owner: String, repo: String, number: Int) async throws -> GitHubIssue {
        let request = try request(path: "repos/\(owner)/\(repo)/issues/\(number)")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decode(GitHubIssue.self, from: data)
    }

    func fetchLabels(owner: String, repo: String) async throws -> [GitHubLabel] {
        let request = try request(path: "repos/\(owner)/\(repo)/labels", query: [URLQueryItem(name: "per_page", value: "100")])
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decode([GitHubLabel].self, from: data)
    }

    func fetchMilestones(owner: String, repo: String) async throws -> [GitHubMilestone] {
        let request = try request(path: "repos/\(owner)/\(repo)/milestones", query: [
            URLQueryItem(name: "per_page", value: "100"),
            URLQueryItem(name: "state", value: "all")
        ])
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decode([GitHubMilestone].self, from: data)
    }

    func fetchAssignees(owner: String, repo: String) async throws -> [GitHubUser] {
        let request = try request(path: "repos/\(owner)/\(repo)/assignees", query: [URLQueryItem(name: "per_page", value: "100")])
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decode([GitHubUser].self, from: data)
    }

    func createIssue(owner: String, repo: String, requestBody: IssueCreateRequest) async throws -> GitHubIssue {
        var request = try request(path: "repos/\(owner)/\(repo)/issues")
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decode(GitHubIssue.self, from: data)
    }

    func updateIssue(owner: String, repo: String, number: Int, requestBody: IssueUpdateRequest) async throws -> GitHubIssue {
        var request = try request(path: "repos/\(owner)/\(repo)/issues/\(number)")
        request.httpMethod = "PATCH"
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decode(GitHubIssue.self, from: data)
    }

    // MARK: - Relationships

    func fetchBlockedBy(owner: String, repo: String, number: Int) async throws -> [GitHubIssueSummary] {
        let request = try request(path: "repos/\(owner)/\(repo)/issues/\(number)/dependencies/blocked_by")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 { return [] }
        if data.isEmpty { return [] }
        return try decode([GitHubIssueSummary].self, from: data)
    }

    func fetchBlocking(owner: String, repo: String, number: Int) async throws -> [GitHubIssueSummary] {
        let request = try request(path: "repos/\(owner)/\(repo)/issues/\(number)/dependencies/blocking")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 { return [] }
        if data.isEmpty { return [] }
        return try decode([GitHubIssueSummary].self, from: data)
    }

    func addBlockedBy(owner: String, repo: String, number: Int, blockedByIssueId: Int) async throws {
        var request = try request(path: "repos/\(owner)/\(repo)/issues/\(number)/dependencies/blocked_by")
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(["issue_id": blockedByIssueId])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try await URLSession.shared.data(for: request)
    }

    func removeBlockedBy(owner: String, repo: String, number: Int, blockedByIssueId: Int) async throws {
        var request = try request(path: "repos/\(owner)/\(repo)/issues/\(number)/dependencies/blocked_by/\(blockedByIssueId)")
        request.httpMethod = "DELETE"
        _ = try await URLSession.shared.data(for: request)
    }

    func fetchParentIssue(owner: String, repo: String, number: Int) async throws -> GitHubIssueSummary? {
        let request = try request(path: "repos/\(owner)/\(repo)/issues/\(number)/sub_issues/parent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 204 || http.statusCode == 404 {
            return nil
        }
        if data.isEmpty { return nil }
        return try decode(GitHubIssueSummary.self, from: data)
    }

    func fetchSubIssues(owner: String, repo: String, number: Int) async throws -> [GitHubIssueSummary] {
        let request = try request(path: "repos/\(owner)/\(repo)/issues/\(number)/sub_issues")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 { return [] }
        if data.isEmpty { return [] }
        return try decode([GitHubIssueSummary].self, from: data)
    }

    func addSubIssue(owner: String, repo: String, parentNumber: Int, subIssueId: Int) async throws {
        var request = try request(path: "repos/\(owner)/\(repo)/issues/\(parentNumber)/sub_issues")
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(["sub_issue_id": subIssueId])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try await URLSession.shared.data(for: request)
    }

    func removeSubIssue(owner: String, repo: String, parentNumber: Int, subIssueId: Int) async throws {
        var request = try request(path: "repos/\(owner)/\(repo)/issues/\(parentNumber)/sub_issues/\(subIssueId)")
        request.httpMethod = "DELETE"
        _ = try await URLSession.shared.data(for: request)
    }
}
