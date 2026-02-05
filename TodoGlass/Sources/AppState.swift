import Foundation
import SwiftUI
import AuthenticationServices

@MainActor
final class AppState: ObservableObject {
    @Published var token: String?
    @Published var currentUser: GitHubUser?
    @Published var repos: [GitHubRepo] = []
    @Published var selectedRepo: GitHubRepo?
    @Published var myIssues: [GitHubIssue] = []
    @Published var allIssues: [GitHubIssue] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authManager = AuthManager()
    private var api: GitHubAPI? {
        guard let token else { return nil }
        return GitHubAPI(token: token)
    }

    func apiClient() -> GitHubAPI? {
        return api
    }

    func setPresentationAnchor(_ anchor: ASPresentationAnchor?) {
        authManager.presentationAnchor = anchor
    }

    private let selectedRepoKey = "selectedRepoFullName"

    init() {
        token = KeychainStore.readToken()
    }

    func bootstrap() async {
        guard token != nil else { return }
        await refreshCurrentUser()
        await loadRepos()
        restoreSelectedRepo()
        if selectedRepo != nil {
            await refreshIssues()
        }
    }

    func signIn() async {
        isLoading = true
        errorMessage = nil
        do {
            let token = try await authManager.signIn()
            KeychainStore.saveToken(token)
            self.token = token
            await refreshCurrentUser()
            await loadRepos()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func handleOpenURL(_ url: URL) {
        authManager.handleCallbackURL(url)
    }

    func signOut() {
        KeychainStore.deleteToken()
        token = nil
        currentUser = nil
        repos = []
        selectedRepo = nil
        myIssues = []
        allIssues = []
        UserDefaults.standard.removeObject(forKey: selectedRepoKey)
    }

    func selectRepo(_ repo: GitHubRepo) {
        selectedRepo = repo
        UserDefaults.standard.setValue(repo.full_name, forKey: selectedRepoKey)
    }

    func loadRepos() async {
        guard let api else { return }
        isLoading = true
        errorMessage = nil
        do {
            repos = try await api.fetchRepos()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refreshIssues(state: String = "open") async {
        guard let api, let repo = selectedRepo, let username = currentUser?.login else { return }
        isLoading = true
        errorMessage = nil
        let owner = repo.owner.login
        let name = repo.name
        do {
            async let my = api.fetchIssues(owner: owner, repo: name, assignee: username, state: state)
            async let all = api.fetchIssues(owner: owner, repo: name, assignee: nil, state: state)
            myIssues = try await my
            allIssues = try await all
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func refreshCurrentUser() async {
        guard let api else { return }
        do {
            currentUser = try await api.fetchCurrentUser()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restoreSelectedRepo() {
        guard let value = UserDefaults.standard.string(forKey: selectedRepoKey) else { return }
        if let match = repos.first(where: { $0.full_name == value }) {
            selectedRepo = match
        }
    }

    func createIssue(title: String, body: String?) async -> GitHubIssue? {
        guard let api, let repo = selectedRepo else { return nil }
        do {
            let defaultAssignees = currentUser.map { [$0.login] }
            let issue = try await api.createIssue(
                owner: repo.owner.login,
                repo: repo.name,
                requestBody: IssueCreateRequest(title: title, body: body, assignees: defaultAssignees, labels: nil, milestone: nil)
            )
            await refreshIssues()
            return issue
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
