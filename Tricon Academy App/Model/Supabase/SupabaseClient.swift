import Foundation

// MARK: - Errors

enum SupabaseError: Error, LocalizedError {
    case notConfigured
    case invalidURL
    case http(Int, String)
    case decoding(Error)
    case encoding
    case noSession
    case message(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase is not configured. Add your project URL and anon key in SupabaseConfig.swift."
        case .invalidURL:
            return "Invalid Supabase URL."
        case .http(let code, let body):
            if body.isEmpty { return "Server error (\(code))." }
            return body
        case .decoding(let error):
            return "Could not read server response: \(error.localizedDescription)"
        case .encoding:
            return "Could not encode request."
        case .noSession:
            return "You are not signed in."
        case .message(let text):
            return text
        }
    }
}

// MARK: - Session

struct SupabaseSession: Codable {
    let accessToken: String
    let refreshToken: String
    /// Unix timestamp (seconds) when the access token expires, if known.
    let expiresAt: TimeInterval?
    let user: SupabaseAuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case expiresIn = "expires_in"
        case user
    }

    init(accessToken: String, refreshToken: String, expiresAt: TimeInterval?, user: SupabaseAuthUser) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        // Prefer explicit expiry; always fall back to JWT `exp` so dashboards can refresh early.
        self.expiresAt = expiresAt ?? SupabaseClient.jwtExpiry(from: accessToken)
        self.user = user
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try c.decodeIfPresent(String.self, forKey: .accessToken) ?? ""
        refreshToken = try c.decodeIfPresent(String.self, forKey: .refreshToken) ?? ""

        // Prefer absolute expiry; fall back to expires_in (relative seconds); then JWT `exp`.
        // GoTrue may send expires_at / expires_in as Int or Double — decode via flexible number.
        let absolute = Self.decodeFlexibleTimeInterval(c, key: .expiresAt)
        let relative = Self.decodeFlexibleTimeInterval(c, key: .expiresIn)
        if let absolute {
            expiresAt = absolute
        } else if let relative {
            expiresAt = Date().timeIntervalSince1970 + relative
        } else {
            expiresAt = SupabaseClient.jwtExpiry(from: accessToken)
        }

        user = try c.decode(SupabaseAuthUser.self, forKey: .user)
    }

    /// Persist only stable fields (never `expires_in`, which is relative to login time).
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(accessToken, forKey: .accessToken)
        try c.encode(refreshToken, forKey: .refreshToken)
        // Prefer stored expiry; re-derive from JWT if missing so reloads stay accurate.
        let exp = expiresAt ?? SupabaseClient.jwtExpiry(from: accessToken)
        try c.encodeIfPresent(exp, forKey: .expiresAt)
        try c.encode(user, forKey: .user)
    }

    private static func decodeFlexibleTimeInterval(
        _ c: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> TimeInterval? {
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
        if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return TimeInterval(i) }
        if let i64 = try? c.decodeIfPresent(Int64.self, forKey: key) { return TimeInterval(i64) }
        if let s = try? c.decodeIfPresent(String.self, forKey: key), let d = Double(s) { return d }
        return nil
    }

    var isExpiredOrExpiringSoon: Bool {
        // Refresh 2 minutes early so Super Admin / Students never hit mid-request expiry.
        let skew: TimeInterval = 120
        let now = Date().timeIntervalSince1970
        if let expiresAt {
            return now >= (expiresAt - skew)
        }
        if let exp = SupabaseClient.jwtExpiry(from: accessToken) {
            return now >= (exp - skew)
        }
        // Unknown expiry — force a refresh rather than risk a 401 on admin screens.
        return true
    }
}

struct SupabaseAuthUser: Codable {
    let id: UUID
    let email: String?

    init(id: UUID, email: String?) {
        self.id = id
        self.email = email
    }
}

// MARK: - Client

/// Lightweight Supabase client (Auth + PostgREST + Storage) over URLSession.
/// Avoids a hard SPM dependency so the project builds on a wide range of Xcode versions.
final class SupabaseClient {
    static let shared = SupabaseClient()

    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // PostgREST returns ISO8601 timestamps
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = ISO8601DateFormatter().date(from: s) { return date }
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Bad date: \(s)")
        }
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let sessionKey = "com.triconacademy.supabase.session"
    private(set) var currentSession: SupabaseSession?

    /// Coalesces concurrent refresh attempts (admin dashboards fire many API calls).
    private let refreshGate = NSLock()
    private var inFlightRefresh: Task<SupabaseSession, Error>?

    var isConfigured: Bool { SupabaseConfig.isConfigured }
    var accessToken: String? { currentSession?.accessToken }
    var userId: UUID? { currentSession?.user.id }

    private init() {
        loadSession()
    }

    // MARK: - Token refresh

    /// Unix `exp` claim from a JWT, if present.
    static func jwtExpiry(from jwt: String) -> TimeInterval? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let exp = json["exp"] as? TimeInterval { return exp }
        if let exp = json["exp"] as? Int { return TimeInterval(exp) }
        if let exp = json["exp"] as? Double { return exp }
        return nil
    }

    /// Refreshes the access token using the stored refresh token.
    @discardableResult
    func refreshSession() async throws -> SupabaseSession {
        try ensureConfigured()
        guard let existing = currentSession, !existing.refreshToken.isEmpty else {
            throw SupabaseError.noSession
        }

        // Single-flight: if another call is already refreshing, await it.
        refreshGate.lock()
        if let inFlight = inFlightRefresh {
            refreshGate.unlock()
            return try await inFlight.value
        }
        let task = Task<SupabaseSession, Error> {
            struct Body: Encodable {
                let refreshToken: String
                enum CodingKeys: String, CodingKey {
                    case refreshToken = "refresh_token"
                }
            }
            // Use raw perform without ensureFresh to avoid recursion.
            let data = try await self.performRaw(
                path: "/auth/v1/token?grant_type=refresh_token",
                method: "POST",
                body: Body(refreshToken: existing.refreshToken),
                rawBody: nil,
                useUserToken: false,
                extraHeaders: [:],
                allowRetryOnAuthFailure: false
            )
            let session = try self.decoder.decode(SupabaseSession.self, from: data)
            guard !session.accessToken.isEmpty else {
                throw SupabaseError.message("Could not refresh your session. Please log in again.")
            }
            self.saveSession(session)
            return session
        }
        inFlightRefresh = task
        refreshGate.unlock()

        defer {
            refreshGate.lock()
            inFlightRefresh = nil
            refreshGate.unlock()
        }

        do {
            return try await task.value
        } catch {
            // Stale refresh token — clear so the UI can send the user back to login.
            if Self.isAuthFailure(error) {
                clearSession()
            }
            throw error
        }
    }

    /// Ensures a usable access token before authenticated API calls.
    func ensureFreshAccessToken() async throws {
        guard let session = currentSession else { throw SupabaseError.noSession }
        guard !session.accessToken.isEmpty else { throw SupabaseError.noSession }
        if session.isExpiredOrExpiringSoon {
            _ = try await refreshSession()
        }
    }

    /// Always refresh once (used before Super Admin / Students dashboards).
    @discardableResult
    func forceRefreshSession() async throws -> SupabaseSession {
        try await refreshSession()
    }

    private static func isAuthFailure(_ error: Error) -> Bool {
        let text = ((error as? LocalizedError)?.errorDescription ?? error.localizedDescription).lowercased()
        return text.contains("jwt expired")
            || text.contains("invalid jwt")
            || text.contains("invalid claim")
            || text.contains("token is expired")
            || text.contains("session not found")
            || text.contains("refresh_token")
            || text.contains("invalid refresh")
    }

    private static func isJWTExpiredResponse(status: Int, body: String, apiMessage: String?) -> Bool {
        if status == 401 { return true }
        let combined = ((apiMessage ?? "") + " " + body).lowercased()
        return combined.contains("jwt expired")
            || combined.contains("invalid jwt")
            || combined.contains("token is expired")
            || combined.contains("not authenticated")
    }

    // MARK: - Auth

    @discardableResult
    func signUp(email: String, password: String, fullName: String, role: String, phone: String? = nil) async throws -> SupabaseSession {
        try ensureConfigured()
        struct Body: Encodable {
            let email: String
            let password: String
            let data: [String: String]
        }
        var meta: [String: String] = ["full_name": fullName, "role": role]
        if let phone, !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            meta["phone"] = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let body = Body(
            email: email,
            password: password,
            data: meta
        )
        let data = try await perform(
            path: "/auth/v1/signup",
            method: "POST",
            body: body,
            rawBody: nil,
            useUserToken: false,
            extraHeaders: [:]
        )

        // Full session (email confirm disabled)
        if let session = try? decoder.decode(SupabaseSession.self, from: data),
           !session.accessToken.isEmpty {
            saveSession(session)
            return session
        }

        // Nested { "session": {...}, "user": {...} }
        struct Nested: Decodable {
            let session: SupabaseSession?
            let user: SupabaseAuthUser?
        }
        if let nested = try? decoder.decode(Nested.self, from: data),
           let session = nested.session,
           !session.accessToken.isEmpty {
            saveSession(session)
            return session
        }

        if let err = try? decoder.decode(SupabaseAPIError.self, from: data), err.hasMessage {
            throw SupabaseError.message(err.displayMessage)
        }

        throw SupabaseError.message(
            "Account created. Confirm your email (or disable Confirm email in Supabase Auth settings), then log in."
        )
    }

    @discardableResult
    func signIn(email: String, password: String) async throws -> SupabaseSession {
        try ensureConfigured()
        struct Body: Encodable {
            let email: String
            let password: String
        }
        let session: SupabaseSession = try await request(
            path: "/auth/v1/token?grant_type=password",
            method: "POST",
            body: Body(email: email, password: password),
            useUserToken: false
        )
        saveSession(session)
        return session
    }

    func signOut() async {
        if isConfigured, currentSession != nil {
            try? await requestVoid(path: "/auth/v1/logout", method: "POST", body: Optional<String>.none, useUserToken: true)
        }
        clearSession()
    }

    func recoverPassword(email: String) async throws {
        try ensureConfigured()
        struct Body: Encodable {
            let email: String
            let redirectTo: String

            enum CodingKeys: String, CodingKey {
                case email
                case redirectTo = "redirect_to"
            }
        }
        // redirect_to must be listed under Supabase Auth → URL Configuration → Redirect URLs
        // so the email does not open localhost.
        try await requestVoid(
            path: "/auth/v1/recover",
            method: "POST",
            body: Body(email: email, redirectTo: SupabaseConfig.authRedirectURL),
            useUserToken: false
        )
    }

    /// Establish a session from recovery / magic-link tokens (deep link).
    func setSession(accessToken: String, refreshToken: String) throws {
        try ensureConfigured()
        // Decode user id from JWT payload (middle segment) without full verification.
        let user = try Self.userFromAccessToken(accessToken) ?? SupabaseAuthUser(id: UUID(), email: nil)
        let session = SupabaseSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Self.jwtExpiry(from: accessToken),
            user: user
        )
        saveSession(session)
    }

    /// Change password while authenticated (used after recovery link opens the app).
    func updatePassword(_ newPassword: String) async throws {
        try ensureConfigured()
        guard currentSession != nil else { throw SupabaseError.noSession }
        struct Body: Encodable {
            let password: String
        }
        try await requestVoid(
            path: "/auth/v1/user",
            method: "PUT",
            body: Body(password: newPassword),
            useUserToken: true
        )
    }

    /// Parse `triconacademy://auth/callback#access_token=...&refresh_token=...&type=recovery`
    /// or query-style tokens.
    static func parseAuthCallbackURL(_ url: URL) -> (accessToken: String, refreshToken: String, type: String?)? {
        var params: [String: String] = [:]

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let items = components.queryItems {
                for item in items {
                    if let value = item.value {
                        params[item.name] = value
                    }
                }
            }
            if let fragment = components.fragment, !fragment.isEmpty {
                for pair in fragment.split(separator: "&") {
                    let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                    if parts.count == 2 {
                        params[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
                    }
                }
            }
        }

        // Some clients pass the whole query as the host/path string
        let absolute = url.absoluteString
        if params["access_token"] == nil, absolute.contains("access_token=") {
            let tail: String
            if let hash = absolute.split(separator: "#").dropFirst().first {
                tail = String(hash)
            } else if let q = absolute.split(separator: "?").dropFirst().first {
                tail = String(q)
            } else {
                tail = absolute
            }
            for pair in tail.split(separator: "&") {
                let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    params[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
                }
            }
        }

        guard let access = params["access_token"], !access.isEmpty,
              let refresh = params["refresh_token"], !refresh.isEmpty else {
            return nil
        }
        return (access, refresh, params["type"])
    }

    private static func userFromAccessToken(_ jwt: String) throws -> SupabaseAuthUser? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let sub = json["sub"] as? String
        let email = json["email"] as? String
        guard let sub, let id = UUID(uuidString: sub) else { return nil }
        return SupabaseAuthUser(id: id, email: email)
    }

    // MARK: - Database (PostgREST)

    func select<T: Decodable>(
        table: String,
        query: String = "",
        single: Bool = false
    ) async throws -> T {
        try ensureConfigured()
        var path = "/rest/v1/\(table)"
        if !query.isEmpty { path += "?\(query)" }
        var headers: [String: String] = [:]
        if single { headers["Accept"] = "application/vnd.pgrst.object+json" }
        return try await request(path: path, method: "GET", body: Optional<String>.none, useUserToken: true, extraHeaders: headers)
    }

    func insert<T: Encodable, R: Decodable>(
        table: String,
        row: T,
        returning: Bool = true
    ) async throws -> R {
        try ensureConfigured()
        var headers: [String: String] = [:]
        if returning {
            headers["Prefer"] = "return=representation"
        }
        let path = "/rest/v1/\(table)"
        // PostgREST returns an array for insert representation
        let results: [R] = try await request(
            path: path,
            method: "POST",
            body: row,
            useUserToken: true,
            extraHeaders: headers
        )
        guard let first = results.first else {
            throw SupabaseError.message("Insert returned no rows.")
        }
        return first
    }

    func insertMany<T: Encodable>(table: String, rows: [T]) async throws {
        try ensureConfigured()
        try await requestVoid(
            path: "/rest/v1/\(table)",
            method: "POST",
            body: rows,
            useUserToken: true,
            extraHeaders: ["Prefer": "return=minimal"]
        )
    }

    func update<T: Encodable>(table: String, query: String, values: T) async throws {
        try ensureConfigured()
        try await requestVoid(
            path: "/rest/v1/\(table)?\(query)",
            method: "PATCH",
            body: values,
            useUserToken: true,
            extraHeaders: ["Prefer": "return=minimal"]
        )
    }

    func delete(table: String, query: String) async throws {
        try ensureConfigured()
        try await requestVoid(
            path: "/rest/v1/\(table)?\(query)",
            method: "DELETE",
            body: Optional<String>.none,
            useUserToken: true,
            extraHeaders: ["Prefer": "return=minimal"]
        )
    }

    // MARK: - Storage

    /// Uploads file bytes to Storage. Returns the storage object path.
    func uploadFile(
        bucket: String,
        path: String,
        data: Data,
        contentType: String
    ) async throws -> String {
        try ensureConfigured()
        let encodedPath = path.split(separator: "/").map {
            $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0)
        }.joined(separator: "/")
        let urlPath = "/storage/v1/object/\(bucket)/\(encodedPath)"
        try await requestVoid(
            path: urlPath,
            method: "POST",
            rawBody: data,
            useUserToken: true,
            extraHeaders: [
                "Content-Type": contentType,
                "x-upsert": "true"
            ]
        )
        return path
    }

    /// Public URL if the bucket is public; otherwise use signed URL for private buckets.
    func publicURL(bucket: String, path: String) -> URL? {
        let base = SupabaseConfig.projectURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let encodedPath = path.split(separator: "/").map {
            $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0)
        }.joined(separator: "/")
        return URL(string: "\(base)/storage/v1/object/public/\(bucket)/\(encodedPath)")
    }

    func downloadData(from remoteURL: URL) async throws -> Data {
        let request = documentDownloadRequest(from: remoteURL)
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw SupabaseError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    func documentDownloadRequest(from remoteURL: URL) -> URLRequest {
        var request = URLRequest(url: remoteURL)
        // External resources must never receive the user's Supabase credentials.
        if let projectURL = URL(string: SupabaseConfig.projectURL),
           remoteURL.scheme == "https", remoteURL.host == projectURL.host,
           remoteURL.port == projectURL.port {
            request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            if let token = accessToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }
        return request
    }

    // MARK: - Session persistence

    func saveSession(_ session: SupabaseSession) {
        currentSession = session
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        }
    }

    private func loadSession() {
        guard let data = UserDefaults.standard.data(forKey: sessionKey),
              let session = try? JSONDecoder().decode(SupabaseSession.self, from: data) else {
            currentSession = nil
            return
        }
        currentSession = session
    }

    func clearSession() {
        currentSession = nil
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    // MARK: - HTTP

    private func ensureConfigured() throws {
        guard isConfigured else { throw SupabaseError.notConfigured }
    }

    private func baseURL() throws -> URL {
        guard let url = URL(string: SupabaseConfig.projectURL) else { throw SupabaseError.invalidURL }
        return url
    }

    private func request<T: Decodable, B: Encodable>(
        path: String,
        method: String,
        body: B?,
        useUserToken: Bool,
        extraHeaders: [String: String] = [:]
    ) async throws -> T {
        let data = try await perform(path: path, method: method, body: body, rawBody: nil, useUserToken: useUserToken, extraHeaders: extraHeaders)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            // Surface server JSON error messages when decode fails
            if let err = try? decoder.decode(SupabaseAPIError.self, from: data) {
                throw SupabaseError.message(err.displayMessage)
            }
            throw SupabaseError.decoding(error)
        }
    }

    private func requestVoid<B: Encodable>(
        path: String,
        method: String,
        body: B?,
        useUserToken: Bool,
        extraHeaders: [String: String] = [:]
    ) async throws {
        let data = try await perform(path: path, method: method, body: body, rawBody: nil, useUserToken: useUserToken, extraHeaders: extraHeaders)
        if let err = try? decoder.decode(SupabaseAPIError.self, from: data), err.hasMessage {
            throw SupabaseError.message(err.displayMessage)
        }
    }

    private func requestVoid(
        path: String,
        method: String,
        rawBody: Data?,
        useUserToken: Bool,
        extraHeaders: [String: String] = [:]
    ) async throws {
        let data = try await perform(path: path, method: method, body: Optional<String>.none, rawBody: rawBody, useUserToken: useUserToken, extraHeaders: extraHeaders)
        if let err = try? decoder.decode(SupabaseAPIError.self, from: data), err.hasMessage {
            throw SupabaseError.message(err.displayMessage)
        }
    }

    func perform<B: Encodable>(
        path: String,
        method: String,
        body: B?,
        rawBody: Data?,
        useUserToken: Bool,
        extraHeaders: [String: String]
    ) async throws -> Data {
        try await performRaw(
            path: path,
            method: method,
            body: body,
            rawBody: rawBody,
            useUserToken: useUserToken,
            extraHeaders: extraHeaders,
            allowRetryOnAuthFailure: true
        )
    }

    /// Core HTTP. When `allowRetryOnAuthFailure` is true, refreshes the JWT once on 401 / JWT expired.
    private func performRaw<B: Encodable>(
        path: String,
        method: String,
        body: B?,
        rawBody: Data?,
        useUserToken: Bool,
        extraHeaders: [String: String],
        allowRetryOnAuthFailure: Bool
    ) async throws -> Data {
        if useUserToken, allowRetryOnAuthFailure {
            // Proactively refresh before admin dashboard / profile queries.
            // Do not swallow failures: a dead refresh must not proceed with a known-expired JWT.
            do {
                try await ensureFreshAccessToken()
            } catch {
                // If we still have a token, attempt the request — executeOnce will 401-retry once more.
                // If we have no session at all, fail fast.
                if currentSession == nil || (accessToken ?? "").isEmpty {
                    throw error
                }
            }
        }

        return try await executeOnce(
            path: path,
            method: method,
            body: body,
            rawBody: rawBody,
            useUserToken: useUserToken,
            extraHeaders: extraHeaders,
            // When refreshing the token itself, never attempt another auth retry.
            didRetryAuth: !allowRetryOnAuthFailure
        )
    }

    private func executeOnce<B: Encodable>(
        path: String,
        method: String,
        body: B?,
        rawBody: Data?,
        useUserToken: Bool,
        extraHeaders: [String: String],
        didRetryAuth: Bool = false
    ) async throws -> Data {
        let root = try baseURL()
        guard let url = URL(string: path, relativeTo: root)?.absoluteURL else {
            throw SupabaseError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if useUserToken {
            guard let token = accessToken, !token.isEmpty else {
                throw SupabaseError.noSession
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        }

        for (k, v) in extraHeaders {
            request.setValue(v, forHTTPHeaderField: k)
        }

        if let rawBody {
            request.httpBody = rawBody
        } else if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.message("No HTTP response.")
        }

        if (200...299).contains(http.statusCode) {
            return data
        }

        let text = String(data: data, encoding: .utf8) ?? ""
        let apiMessage = (try? decoder.decode(SupabaseAPIError.self, from: data))?.displayMessage

        // Expired / invalid access token → refresh once and retry (Super Admin / Students).
        if useUserToken,
           !didRetryAuth,
           Self.isJWTExpiredResponse(status: http.statusCode, body: text, apiMessage: apiMessage) {
            do {
                _ = try await refreshSession()
                return try await executeOnce(
                    path: path,
                    method: method,
                    body: body,
                    rawBody: rawBody,
                    useUserToken: useUserToken,
                    extraHeaders: extraHeaders,
                    didRetryAuth: true
                )
            } catch {
                // Do not clear tokens here — AuthManager decides logout vs retry.
                // Clearing mid-request would desync the app UI from the cloud session.
                throw SupabaseError.message(
                    "Your session expired. Please log out and log in again, then open Students or Super Admin."
                )
            }
        }

        if let apiMessage, !apiMessage.isEmpty, apiMessage != "Unknown error" {
            throw SupabaseError.message(apiMessage)
        }
        throw SupabaseError.http(http.statusCode, text)
    }
}

// MARK: - API error payload

private struct SupabaseAPIError: Decodable {
    let error: String?
    let errorDescription: String?
    let msg: String?
    let message: String?
    let errorCode: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
        case msg
        case message
        case errorCode = "error_code"
    }

    var hasMessage: Bool {
        displayMessage != "Unknown error"
    }

    var displayMessage: String {
        if let errorDescription, !errorDescription.isEmpty { return errorDescription }
        if let message, !message.isEmpty { return message }
        if let msg, !msg.isEmpty { return msg }
        if let error, !error.isEmpty { return error }
        return "Unknown error"
    }
}
