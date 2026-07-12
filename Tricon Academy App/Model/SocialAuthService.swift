import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

enum SocialAuthError: LocalizedError {
    case cancelled
    case missingCredential
    case googleNotConfigured
    case googleFailed(String)
    case appleFailed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Sign-in was cancelled."
        case .missingCredential:
            return "Could not read your account details. Please try again."
        case .googleNotConfigured:
            return "Google Sign-In isn’t configured yet. Add your iOS OAuth Client ID in EmailConfig.swift (Google Cloud Console → Credentials)."
        case .googleFailed(let message):
            return message
        case .appleFailed(let message):
            return message
        }
    }
}

struct SocialAuthProfile {
    let id: String
    let email: String
    let fullName: String
    let provider: SocialProvider
}

enum SocialProvider: String {
    case apple
    case google
}

/// Handles Sign in with Apple (native) and Google (OAuth + PKCE via ASWebAuthenticationSession).
final class SocialAuthService: NSObject {

    static let shared = SocialAuthService()

    private var appleContinuation: CheckedContinuation<SocialAuthProfile, Error>?
    private var presentationAnchor: ASPresentationAnchor?

    // MARK: - Apple

    @MainActor
    func signInWithApple(anchor: ASPresentationAnchor) async throws -> SocialAuthProfile {
        presentationAnchor = anchor
        let nonce = Self.randomNonce()

        return try await withCheckedThrowingContinuation { continuation in
            self.appleContinuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = Self.sha256Hex(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Google

    @MainActor
    func signInWithGoogle(anchor: ASPresentationAnchor) async throws -> SocialAuthProfile {
        guard EmailConfig.isGoogleConfigured,
              let scheme = EmailConfig.googleURLScheme else {
            throw SocialAuthError.googleNotConfigured
        }

        let verifier = Self.randomNonce(length: 64)
        let challenge = Self.base64URL(Self.sha256Data(verifier))

        guard let authURL = Self.googleAuthURL(redirectScheme: scheme, codeChallenge: challenge) else {
            throw SocialAuthError.googleFailed("Could not build Google authorization URL.")
        }

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: scheme
            ) { url, error in
                if let error {
                    let ns = error as NSError
                    if ns.domain == ASWebAuthenticationSessionErrorDomain,
                       ns.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: SocialAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: SocialAuthError.googleFailed(error.localizedDescription))
                    }
                    return
                }
                guard let url else {
                    continuation.resume(throwing: SocialAuthError.missingCredential)
                    return
                }
                continuation.resume(returning: url)
            }
            session.presentationContextProvider = GooglePresentationContext(anchor: anchor)
            session.prefersEphemeralWebBrowserSession = false
            if !session.start() {
                continuation.resume(throwing: SocialAuthError.googleFailed("Unable to start Google sign-in."))
            }
        }

        if let err = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "error" })?
            .value {
            throw SocialAuthError.googleFailed("Google error: \(err)")
        }

        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value else {
            throw SocialAuthError.googleFailed("Google did not return an authorization code.")
        }

        let tokens = try await Self.exchangeGoogleCode(code, redirectScheme: scheme, codeVerifier: verifier)
        return try await Self.fetchGoogleProfile(accessToken: tokens.accessToken)
    }

    // MARK: - Google helpers

    private static func googleAuthURL(redirectScheme: String, codeChallenge: String) -> URL? {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: EmailConfig.googleClientID),
            URLQueryItem(name: "redirect_uri", value: "\(redirectScheme):/oauth2redirect/google"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "include_granted_scopes", value: "true"),
            URLQueryItem(name: "prompt", value: "select_account")
        ]
        return components?.url
    }

    private struct GoogleTokenResponse: Decodable {
        let access_token: String
        var accessToken: String { access_token }
    }

    private struct GoogleUserInfo: Decodable {
        let sub: String
        let email: String?
        let name: String?
        let given_name: String?
        let family_name: String?
    }

    private static func exchangeGoogleCode(_ code: String, redirectScheme: String, codeVerifier: String) async throws -> GoogleTokenResponse {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            throw SocialAuthError.googleFailed("Invalid token endpoint.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params: [(String, String)] = [
            ("code", code),
            ("client_id", EmailConfig.googleClientID),
            ("redirect_uri", "\(redirectScheme):/oauth2redirect/google"),
            ("grant_type", "authorization_code"),
            ("code_verifier", codeVerifier)
        ]
        request.httpBody = params
            .map { key, value in
                let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(key)=\(encoded)"
            }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "Token exchange failed"
            throw SocialAuthError.googleFailed("Google token error: \(detail)")
        }

        return try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
    }

    private static func fetchGoogleProfile(accessToken: String) async throws -> SocialAuthProfile {
        guard let url = URL(string: "https://www.googleapis.com/oauth2/v3/userinfo") else {
            throw SocialAuthError.googleFailed("Invalid userinfo endpoint.")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SocialAuthError.googleFailed("Could not load Google profile.")
        }

        let info = try JSONDecoder().decode(GoogleUserInfo.self, from: data)
        guard let email = info.email, !email.isEmpty else {
            throw SocialAuthError.missingCredential
        }

        let name: String
        if let full = info.name, !full.isEmpty {
            name = full
        } else {
            let parts = [info.given_name, info.family_name].compactMap { $0 }.filter { !$0.isEmpty }
            name = parts.isEmpty ? (email.components(separatedBy: "@").first ?? "Student") : parts.joined(separator: " ")
        }

        return SocialAuthProfile(id: info.sub, email: email, fullName: name, provider: .google)
    }

    // MARK: - Crypto helpers

    private static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
            }
            if Int(random) < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256Hex(_ input: String) -> String {
        sha256Data(input).map { String(format: "%02x", $0) }.joined()
    }

    private static func sha256Data(_ input: String) -> Data {
        Data(SHA256.hash(data: Data(input.utf8)))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Apple delegates

extension SocialAuthService: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            appleContinuation?.resume(throwing: SocialAuthError.missingCredential)
            appleContinuation = nil
            return
        }

        let userId = credential.user
        let email = credential.email
            ?? UserDefaults.standard.string(forKey: "apple.email.\(userId)")
            ?? "\(userId.prefix(8))@privaterelay.appleid.com"

        if let email = credential.email {
            UserDefaults.standard.set(email, forKey: "apple.email.\(userId)")
        }

        var nameParts: [String] = []
        if let given = credential.fullName?.givenName { nameParts.append(given) }
        if let family = credential.fullName?.familyName { nameParts.append(family) }

        let fullName: String
        if !nameParts.isEmpty {
            fullName = nameParts.joined(separator: " ")
            UserDefaults.standard.set(fullName, forKey: "apple.name.\(userId)")
        } else {
            fullName = UserDefaults.standard.string(forKey: "apple.name.\(userId)") ?? "Apple User"
        }

        let profile = SocialAuthProfile(
            id: userId,
            email: email,
            fullName: fullName,
            provider: .apple
        )
        appleContinuation?.resume(returning: profile)
        appleContinuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let ns = error as NSError
        if ns.code == ASAuthorizationError.canceled.rawValue {
            appleContinuation?.resume(throwing: SocialAuthError.cancelled)
        } else {
            appleContinuation?.resume(throwing: SocialAuthError.appleFailed(error.localizedDescription))
        }
        appleContinuation = nil
    }
}

extension SocialAuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let presentationAnchor {
            return presentationAnchor
        }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// MARK: - Google presentation

private final class GooglePresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    let anchor: ASPresentationAnchor
    init(anchor: ASPresentationAnchor) { self.anchor = anchor }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }
}
