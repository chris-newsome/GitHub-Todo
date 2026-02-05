import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

enum OAuthError: LocalizedError {
    case invalidCallback
    case missingCode
    case stateMismatch
    case tokenExchangeFailed

    var errorDescription: String? {
        switch self {
        case .invalidCallback:
            return "Invalid OAuth callback."
        case .missingCode:
            return "Authorization code missing."
        case .stateMismatch:
            return "OAuth state mismatch."
        case .tokenExchangeFailed:
            return "Failed to exchange token."
        }
    }
}

@MainActor
final class AuthManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    var presentationAnchor: ASPresentationAnchor?
    private var pendingContinuation: CheckedContinuation<String, Error>?
    private var pendingState: String?
    private var pendingVerifier: String?

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let anchor = presentationAnchor { return anchor }
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        let window = windowScene?.windows.first { $0.isKeyWindow }
        return window ?? ASPresentationAnchor()
    }

    func signIn() async throws -> String {
        if pendingContinuation != nil {
            throw OAuthError.invalidCallback
        }
        let state = UUID().uuidString
        let codeVerifier = Self.randomVerifier()
        let codeChallenge = Self.codeChallenge(for: codeVerifier)

        var components = URLComponents(url: AppConfig.githubAuthURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: AppConfig.githubClientId),
            URLQueryItem(name: "redirect_uri", value: AppConfig.redirectURI),
            URLQueryItem(name: "scope", value: AppConfig.oauthScope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let authURL = components?.url else { throw OAuthError.invalidCallback }
        pendingState = state
        pendingVerifier = codeVerifier

        return try await withCheckedThrowingContinuation { continuation in
            pendingContinuation = continuation
            session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "todoglass") { [weak self] url, error in
                guard let self else { return }
                if let error {
                    self.resumePending(with: .failure(error))
                    return
                }
                if let url {
                    self.handleCallbackURL(url)
                } else {
                    self.resumePending(with: .failure(OAuthError.invalidCallback))
                }
            }
            session?.presentationContextProvider = self
            session?.prefersEphemeralWebBrowserSession = false
            if session?.start() == false {
                UIApplication.shared.open(authURL)
            }
        }
    }

    func handleCallbackURL(_ url: URL) {
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            resumePending(with: .failure(OAuthError.invalidCallback))
            return
        }

        let items = urlComponents.queryItems ?? []
        let code = items.first(where: { $0.name == "code" })?.value
        let returnedState = items.first(where: { $0.name == "state" })?.value

        guard let pendingState else {
            resumePending(with: .failure(OAuthError.stateMismatch))
            return
        }
        guard returnedState == pendingState else {
            resumePending(with: .failure(OAuthError.stateMismatch))
            return
        }
        guard let code, let verifier = pendingVerifier else {
            resumePending(with: .failure(OAuthError.missingCode))
            return
        }

        Task {
            do {
                let token = try await exchangeCodeForToken(code: code, codeVerifier: verifier)
                resumePending(with: .success(token))
            } catch {
                resumePending(with: .failure(error))
            }
        }
    }

    private func resumePending(with result: Result<String, Error>) {
        guard let continuation = pendingContinuation else { return }
        pendingContinuation = nil
        pendingState = nil
        pendingVerifier = nil
        switch result {
        case .success(let token):
            continuation.resume(returning: token)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    private func exchangeCodeForToken(code: String, codeVerifier: String) async throws -> String {
        var request = URLRequest(url: AppConfig.githubTokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: AppConfig.githubClientId),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: codeVerifier),
            URLQueryItem(name: "redirect_uri", value: AppConfig.redirectURI)
        ]
        if !AppConfig.githubClientSecret.isEmpty {
            components.queryItems?.append(
                URLQueryItem(name: "client_secret", value: AppConfig.githubClientSecret)
            )
        }
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let payload = try? JSONDecoder().decode(OAuthTokenResponse.self, from: data),
           let token = payload.access_token {
            return token
        }

        if let errorPayload = parseErrorResponse(data: data, response: response) {
            throw NSError(domain: "OAuthError", code: 1, userInfo: [NSLocalizedDescriptionKey: errorPayload])
        }

        throw OAuthError.tokenExchangeFailed
    }

    private static func randomVerifier() -> String {
        let charset = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        var result = ""
        result.reserveCapacity(64)
        for _ in 0..<64 {
            result.append(charset[Int.random(in: 0..<charset.count)])
        }
        return result
    }

    private static func codeChallenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hashed = SHA256.hash(data: data)
        return Data(hashed).base64URLEncodedString()
    }
}

struct OAuthTokenResponse: Decodable {
    let access_token: String?
    let scope: String?
    let token_type: String?
}

private func parseErrorResponse(data: Data, response: URLResponse) -> String? {
    if let json = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
        if let description = json.error_description {
            return description
        }
        return json.error
    }

    if let text = String(data: data, encoding: .utf8) {
        if text.contains("error=") {
            let components = URLComponents(string: "https://example.com/?" + text)
            let error = components?.queryItems?.first(where: { $0.name == "error" })?.value
            let description = components?.queryItems?.first(where: { $0.name == "error_description" })?.value
            return description ?? error
        }
    }

    return nil
}

private struct OAuthErrorResponse: Decodable {
    let error: String
    let error_description: String?
    let error_uri: String?
}

private extension Data {
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
