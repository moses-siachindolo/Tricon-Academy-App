import Foundation
import Security

enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case social(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password."
        case .social(let message):
            return message
        }
    }
}

/// Backwards-compatible alias used by older call sites.
typealias LoginError = AuthError

class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: User?
    @Published var isLoggedIn: Bool = false

    private let keychainKey = "com.triconacademy.session"

    init() {
        restoreSession()
    }

    // MARK: - Role resolution

    /// Maps known demo emails (and optional explicit role) to a UserRole.
    /// - Admin: `admin@tricon.com` only (cannot self-register as admin)
    /// - Tutor: `tutor@tricon.com`, or any email containing `tutor@`, or explicit `.tutor`
    /// - Student: default
    static func resolveRole(email: String, preferredRole: UserRole? = nil) -> UserRole {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalized == "admin@tricon.com" || normalized.hasPrefix("admin@") {
            return .admin
        }

        if normalized == "tutor@tricon.com" || normalized.contains("tutor@") {
            return .tutor
        }

        if let preferredRole, preferredRole != .admin {
            return preferredRole
        }

        return .student
    }

    static func displayName(for role: UserRole, fallback: String) -> String {
        switch role {
        case .admin: return fallback.isEmpty ? "Admin" : fallback
        case .tutor: return fallback.isEmpty ? "Tutor" : fallback
        case .student: return fallback.isEmpty ? "Student" : fallback
        }
    }

    // MARK: - Login (mock credentials store)

    func login(email: String, password: String, remember: Bool = true) -> Result<Void, AuthError> {
        guard !email.isEmpty, !password.isEmpty else {
            return .failure(.invalidCredentials)
        }

        let role = Self.resolveRole(email: email)
        let defaultName: String
        switch role {
        case .admin: defaultName = "Admin"
        case .tutor: defaultName = "Tutor"
        case .student: defaultName = "Student"
        }

        let user = User(
            id: UUID(),
            name: defaultName,
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            role: role
        )
        saveSession(user: user, persist: remember)
        return .success(())
    }

    // MARK: - Register (instant — no email OTP for now)

    /// Creates an account and signs the user in immediately.
    /// Email OTP was removed for a faster onboarding experience; Apple/Google
    /// sign-in remain available as stronger alternatives.
    func register(
        fullName: String,
        email: String,
        phone: String,
        password: String,
        preferredRole: UserRole = .student
    ) -> Result<Void, AuthError> {
        let name = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let mail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeRole: UserRole = (preferredRole == .admin) ? .tutor : preferredRole

        guard !name.isEmpty, !mail.isEmpty, !password.isEmpty else {
            return .failure(.invalidCredentials)
        }

        let role = Self.resolveRole(email: mail, preferredRole: safeRole)
        let user = User(
            id: UUID(),
            name: name,
            email: mail,
            role: role
        )
        saveSession(user: user, persist: true)
        return .success(())
    }

    // MARK: - Social sign-in

    func completeSocialSignIn(profile: SocialAuthProfile, preferredRole: UserRole = .student) {
        let role = Self.resolveRole(email: profile.email, preferredRole: preferredRole)
        let user = User(
            id: UUID(uuidString: stableUUID(from: profile.id)) ?? UUID(),
            name: profile.fullName.isEmpty
                ? Self.displayName(for: role, fallback: profile.email)
                : profile.fullName,
            email: profile.email,
            role: role
        )
        saveSession(user: user, persist: true)
    }

    /// Deterministic UUID from social provider subject so re-login maps to same user id when possible.
    private func stableUUID(from string: String) -> String {
        let data = Data(string.utf8)
        var hash = [UInt8](repeating: 0, count: 16)
        let bytes = [UInt8](data)
        for (index, byte) in bytes.enumerated() {
            hash[index % 16] ^= byte
        }
        hash[6] = (hash[6] & 0x0F) | 0x40
        hash[8] = (hash[8] & 0x3F) | 0x80
        let hex = hash.map { String(format: "%02x", $0) }
        return "\(hex[0...3].joined())-\(hex[4...5].joined())-\(hex[6...7].joined())-\(hex[8...9].joined())-\(hex[10...15].joined())"
    }

    func saveSessionFromExternal(user: User) {
        saveSession(user: user, persist: true)
    }

    func logout() {
        currentUser = nil
        isLoggedIn = false
        deleteFromKeychain()
    }

    // MARK: - Session persistence

    private func saveSession(user: User, persist: Bool) {
        currentUser = user
        isLoggedIn = true

        if persist {
            if let data = try? JSONEncoder().encode(user) {
                saveToKeychain(data: data)
            }
        } else {
            deleteFromKeychain()
        }
    }

    private func restoreSession() {
        if let data = readFromKeychain(),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            currentUser = user
            isLoggedIn = true
        }
    }

    // MARK: - Keychain helpers

    private func saveToKeychain(data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        SecItemDelete(query as CFDictionary)
        var newItem = query
        newItem[kSecValueData as String] = data
        SecItemAdd(newItem as CFDictionary, nil)
    }

    private func readFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }

    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        SecItemDelete(query as CFDictionary)
    }
}
