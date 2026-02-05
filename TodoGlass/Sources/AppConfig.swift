import Foundation

enum AppConfig {
    static let githubClientId = "Ov23li2l6jn5TWExGggO"
    // Optional. GitHub OAuth Apps sometimes require client_secret on token exchange.
    // Leave empty for pure PKCE public-client flow.
    static let githubClientSecret = "48aee07bbe0121962375bd548640f6786421a01f"
    static let redirectURI = "todoglass://oauth/callback"
    static let oauthScope = "public_repo"
    static let githubAPIBase = URL(string: "https://api.github.com")!
    static let githubAuthURL = URL(string: "https://github.com/login/oauth/authorize")!
    static let githubTokenURL = URL(string: "https://github.com/login/oauth/access_token")!
}
