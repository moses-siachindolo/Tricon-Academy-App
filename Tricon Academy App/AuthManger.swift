import Foundation
import CryptoKit
import Security

enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case accountNotFound
    case emailAlreadyRegistered
    case social(String)
    case remote(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Incorrect email or password."
        case .accountNotFound:
            return "No account found for this email. Please sign up first."
        case .emailAlreadyRegistered:
            return "An account with this email already exists. Log in to continue — if you applied as a tutor, use Log in to check approval status. Do not create a new account."
        case .social(let message):
            return message
        case .remote(let message):
            return message
        }
    }
}

typealias LoginError = AuthError

private struct StoredAccount: Codable {
    let id: UUID
    var name: String
    var email: String
    var role: UserRole
    var passwordHash: String
    var school: String?
    var schoolDistrict: String?
    var grade: String?
    var profileCompleted: Bool?
    var isBlocked: Bool?
    var isRemoved: Bool?
    var phone: String?
    var highestEducation: String?
    var lastInstitution: String?
    var gender: String?
    var addressLocation: String?
    var subjectMajor: String?
    var referenceContacts: String?
    var tutorApprovalStatus: String?
    var adminStatusReason: String?
    var allowedExtraSubjects: String?
    var pendingSubjectRequest: String?

    init(
        id: UUID,
        name: String,
        email: String,
        role: UserRole,
        passwordHash: String,
        school: String? = nil,
        schoolDistrict: String? = nil,
        grade: String? = nil,
        profileCompleted: Bool? = nil,
        isBlocked: Bool? = nil,
        isRemoved: Bool? = nil,
        phone: String? = nil,
        highestEducation: String? = nil,
        lastInstitution: String? = nil,
        gender: String? = nil,
        addressLocation: String? = nil,
        subjectMajor: String? = nil,
        referenceContacts: String? = nil,
        tutorApprovalStatus: String? = nil,
        adminStatusReason: String? = nil,
        allowedExtraSubjects: String? = nil,
        pendingSubjectRequest: String? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        self.passwordHash = passwordHash
        self.school = school
        self.schoolDistrict = schoolDistrict
        self.grade = grade
        self.profileCompleted = profileCompleted
        self.isBlocked = isBlocked
        self.isRemoved = isRemoved
        self.phone = phone
        self.highestEducation = highestEducation
        self.lastInstitution = lastInstitution
        self.gender = gender
        self.addressLocation = addressLocation
        self.subjectMajor = subjectMajor
        self.referenceContacts = referenceContacts
        self.tutorApprovalStatus = tutorApprovalStatus
        self.adminStatusReason = adminStatusReason
        self.allowedExtraSubjects = allowedExtraSubjects
        self.pendingSubjectRequest = pendingSubjectRequest
    }

    var isAccessDenied: Bool {
        isBlocked == true || isRemoved == true
    }

    var asUser: User {
        User(
            id: id,
            name: name,
            email: email,
            role: role,
            school: school,
            schoolDistrict: schoolDistrict,
            grade: grade,
            profileCompleted: profileCompleted ?? (role != .student),
            phone: phone,
            adminStatusReason: adminStatusReason,
            highestEducation: highestEducation,
            lastInstitution: lastInstitution,
            gender: gender,
            addressLocation: addressLocation,
            subjectMajor: subjectMajor,
            referenceContacts: referenceContacts,
            tutorApprovalStatus: tutorApprovalStatus,
            allowedExtraSubjects: allowedExtraSubjects,
            pendingSubjectRequest: pendingSubjectRequest
        )
    }

    var asRemoteProfile: RemoteProfile {
        RemoteProfile(
            id: id,
            fullName: name,
            email: email,
            role: role.rawValue,
            phone: phone,
            school: school,
            schoolDistrict: schoolDistrict,
            grade: grade,
            profileCompleted: profileCompleted,
            isBlocked: isBlocked,
            isRemoved: isRemoved,
            highestEducation: highestEducation,
            lastInstitution: lastInstitution,
            gender: gender,
            addressLocation: addressLocation,
            subjectMajor: subjectMajor,
            referenceContacts: referenceContacts,
            tutorApprovalStatus: tutorApprovalStatus,
            adminStatusReason: adminStatusReason,
            allowedExtraSubjects: allowedExtraSubjects,
            pendingSubjectRequest: pendingSubjectRequest,
            createdAt: nil
        )
    }
}

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: User? {
        didSet {
            if oldValue?.id != currentUser?.id { authGeneration += 1 }
            SavedItemsManager.shared.setUser(currentUser?.id)
        }
    }
    @Published var isLoggedIn: Bool = false
    @Published private(set) var isCloudEnabled: Bool = SupabaseConfig.isConfigured
    /// True after user opens a password-recovery deep link; show set-new-password UI.
    @Published var needsPasswordResetCompletion: Bool = false
    @Published var deepLinkError: String?
    @Published var accountAccessMessage: String?
    private var authGeneration = 0

    private let sessionKeychainKey = "com.triconacademy.session"
    private let accountsKeychainKey = "com.triconacademy.accounts"
    private let client = SupabaseClient.shared

    private init() {
        seedDefaultAccountsIfNeeded()
        Task { await restoreSession() }
    }

    /// Handle `triconacademy://auth/callback#access_token=...&type=recovery`
    func handleOpenURL(_ url: URL) {
        guard url.scheme?.lowercased() == "triconacademy" else { return }
        deepLinkError = nil

        guard let tokens = SupabaseClient.parseAuthCallbackURL(url) else {
            deepLinkError = "This reset link is invalid or incomplete. Request a new password email."
            return
        }

        do {
            try client.setSession(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
        } catch {
            deepLinkError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return
        }

        // Only recovery links require the set-new-password sheet.
        // Other callbacks (invite, magiclink, signup) should restore a normal session.
        if tokens.type == "recovery" {
            needsPasswordResetCompletion = true
            // Do not mark fully logged-in until password is set (avoids landing in main app mid-reset).
            isLoggedIn = false
            currentUser = nil
        } else {
            Task { await restoreSessionFromCloudTokens() }
        }
    }

    /// Called from the in-app “Set new password” screen after opening the email link.
    func completePasswordReset(newPassword: String) async -> Result<Void, AuthError> {
        guard newPassword.count >= 6 else {
            return .failure(.remote("Password must be at least 6 characters."))
        }
        guard client.currentSession != nil else {
            return .failure(.remote("Reset session expired. Request a new password email and open the link again."))
        }

        do {
            try await client.updatePassword(newPassword)
            // Load profile and sign the user in
            if let session = client.currentSession {
                let profile = try await fetchOrCreateProfile(
                    userId: session.user.id,
                    email: session.user.email ?? "",
                    fallbackName: session.user.email?.components(separatedBy: "@").first ?? "User",
                    role: .student
                )
                if let message = accessDeniedMessage(for: profile) {
                    signOutForAccountRestriction(message)
                    return .failure(.remote(message))
                }
                saveSession(user: profile.asUser, persist: true)
                Task.detached(priority: .utility) {
                    await ContentLibrary.shared.refreshFromCloud()
                }
            }
            needsPasswordResetCompletion = false
            deepLinkError = nil
            return .success(())
        } catch {
            return .failure(mapRemoteError(error))
        }
    }

    func cancelPasswordResetFlow() {
        needsPasswordResetCompletion = false
        client.clearSession()
    }

    private func restoreSessionFromCloudTokens() async {
        guard let session = client.currentSession else { return }
        do {
            let profile = try await fetchOrCreateProfile(
                userId: session.user.id,
                email: session.user.email ?? "",
                fallbackName: session.user.email?.components(separatedBy: "@").first ?? "User",
                role: .student
            )
            if let message = accessDeniedMessage(for: profile) {
                signOutForAccountRestriction(message)
                return
            }
            saveSession(user: profile.asUser, persist: true)
            Task.detached(priority: .utility) {
                await ContentLibrary.shared.refreshFromCloud()
            }
        } catch {
            deepLinkError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Seed (local mode only)

    private func seedDefaultAccountsIfNeeded() {
        // Never seed offline demo accounts when Supabase is configured.
        guard !client.isConfigured else { return }
        guard loadAccounts().isEmpty else { return }
        let seeded = [
            StoredAccount(
                id: UUID(),
                name: "Admin",
                email: "mosesadmin@tricon.com",
                role: .admin,
                passwordHash: Self.hash(password: "moses@2026")
            ),
            StoredAccount(
                id: UUID(),
                name: "Tutor",
                email: "mosestutor@tricon.com",
                role: .tutor,
                passwordHash: Self.hash(password: "moses@2026"),
                subjectMajor: "Mathematics, Physics",
                tutorApprovalStatus: TutorApprovalStatus.approved.rawValue
            )
        ]
        saveAccounts(seeded)
    }

    // MARK: - Login

    func login(email: String, password: String, remember: Bool = true) async -> Result<Void, AuthError> {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty, !password.isEmpty else {
            return .failure(.invalidCredentials)
        }

        if client.isConfigured {
            return await loginRemote(email: normalizedEmail, password: password, remember: remember)
        }
        return loginLocal(email: normalizedEmail, password: password, remember: remember)
    }

    private func loginRemote(email: String, password: String, remember: Bool) async -> Result<Void, AuthError> {
        do {
            let session = try await client.signIn(email: email, password: password)
            let profile = try await fetchOrCreateProfile(
                userId: session.user.id,
                email: email,
                fallbackName: email.components(separatedBy: "@").first ?? "User",
                role: .student
            )
            if let deny = accessDeniedMessage(for: profile) {
                await client.signOut()
                return .failure(.remote(deny))
            }
            saveSession(user: profile.asUser, persist: remember)
            // Content sync in background so a slow/dead server cannot freeze login or navigation.
            Task.detached(priority: .utility) {
                await ContentLibrary.shared.refreshFromCloud()
            }
            return .success(())
        } catch {
            return .failure(mapRemoteError(error))
        }
    }

    private func loginLocal(email: String, password: String, remember: Bool) -> Result<Void, AuthError> {
        let accounts = loadAccounts()
        guard let account = accounts.first(where: { $0.email.lowercased() == email }) else {
            return .failure(.accountNotFound)
        }
        guard account.passwordHash == Self.hash(password: password) else {
            return .failure(.invalidCredentials)
        }
        if account.isRemoved == true {
            let reason = account.adminStatusReason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !reason.isEmpty {
                return .failure(.remote("This account has been removed. Reason: \(reason)"))
            }
            return .failure(.remote("This account has been removed from Tricon Academy."))
        }
        if account.isBlocked == true {
            let reason = account.adminStatusReason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !reason.isEmpty {
                return .failure(.remote("This account has been blocked. Reason: \(reason)\n\nContact \(AcademySupport.phoneDisplay) or \(AcademySupport.email) if you need help."))
            }
            return .failure(.remote("This account has been blocked. Contact \(AcademySupport.phoneDisplay) or \(AcademySupport.email)."))
        }
        saveSession(user: account.asUser, persist: remember)
        return .success(())
    }

    private func accessDeniedMessage(for profile: RemoteProfile) -> String? {
        if profile.isAccountRemoved {
            let reason = profile.adminStatusReason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !reason.isEmpty {
                return "This account has been removed. Reason: \(reason)"
            }
            return "This account has been removed from Tricon Academy."
        }
        if profile.isAccountBlocked {
            let reason = profile.adminStatusReason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !reason.isEmpty {
                return "This account has been blocked. Reason: \(reason)\n\nContact \(AcademySupport.phoneDisplay) or \(AcademySupport.email) if you need help."
            }
            return "This account has been blocked. Contact \(AcademySupport.phoneDisplay) or \(AcademySupport.email)."
        }
        return nil
    }

    // MARK: - Register

    func register(
        fullName: String,
        email: String,
        phone: String,
        password: String,
        preferredRole: UserRole = .student
    ) async -> Result<Void, AuthError> {
        let name = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let safeRole: UserRole = (preferredRole == .admin) ? .tutor : preferredRole

        guard !name.isEmpty, !normalizedEmail.isEmpty, !password.isEmpty else {
            return .failure(.invalidCredentials)
        }

        if client.isConfigured {
            return await registerRemote(
                name: name,
                email: normalizedEmail,
                phone: phone,
                password: password,
                role: safeRole
            )
        }
        return registerLocal(
            name: name,
            email: normalizedEmail,
            password: password,
            role: safeRole,
            phone: phone
        )
    }

    private func registerRemote(
        name: String,
        email: String,
        phone: String,
        password: String,
        role: UserRole
    ) async -> Result<Void, AuthError> {
        do {
            let session = try await client.signUp(
                email: email,
                password: password,
                fullName: name,
                role: role.rawValue,
                phone: phone
            )
            var profile = try await fetchOrCreateProfile(
                userId: session.user.id,
                email: email,
                fallbackName: name,
                role: role,
                phone: phone
            )
            // Trigger-created profiles often miss phone (and sometimes role/name).
            // Patch any missing fields so registration data is not silently dropped.
            let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
            let needsPhone = !trimmedPhone.isEmpty && (profile.phone?.isEmpty ?? true)
            let needsName = profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || profile.fullName == email.components(separatedBy: "@").first
            let needsRole = profile.userRole != role && role != .admin
            if needsPhone || needsName || needsRole {
                struct ProfileRegistrationPatch: Encodable {
                    var fullName: String?
                    var phone: String?
                    var role: String?
                    enum CodingKeys: String, CodingKey {
                        case fullName = "full_name"
                        case phone
                        case role
                    }
                    func encode(to encoder: Encoder) throws {
                        var c = encoder.container(keyedBy: CodingKeys.self)
                        if let fullName { try c.encode(fullName, forKey: .fullName) }
                        if let phone { try c.encode(phone, forKey: .phone) }
                        if let role { try c.encode(role, forKey: .role) }
                    }
                }
                let patch = ProfileRegistrationPatch(
                    fullName: needsName ? name : nil,
                    phone: needsPhone ? trimmedPhone : nil,
                    role: needsRole ? role.rawValue : nil
                )
                try? await client.update(
                    table: "profiles",
                    query: "id=eq.\(session.user.id.uuidString)",
                    values: patch
                )
                if needsPhone { profile.phone = trimmedPhone }
                if needsName { profile.fullName = name }
                if needsRole { profile.role = role.rawValue }
            }
            var user = profile.asUser
            if user.phone == nil || user.phone?.isEmpty == true {
                user.phone = trimmedPhone.isEmpty ? phone : trimmedPhone
            }
            if user.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                user.name = name
            }
            // Prefer the role chosen at signup if the profile trigger lagged.
            if role != .admin, user.role != role {
                user.role = role
            }
            // New tutors must complete verification — never land as "legacy approved".
            if role == .tutor {
                let status = user.tutorApprovalStatus?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if status.isEmpty || status == TutorApprovalStatus.none.rawValue {
                    let none = TutorApprovalStatus.none.rawValue
                    struct TutorStatusPatch: Encodable {
                        let tutorApprovalStatus: String
                        enum CodingKeys: String, CodingKey {
                            case tutorApprovalStatus = "tutor_approval_status"
                        }
                    }
                    try? await client.update(
                        table: "profiles",
                        query: "id=eq.\(session.user.id.uuidString)",
                        values: TutorStatusPatch(tutorApprovalStatus: none)
                    )
                    user.tutorApprovalStatus = none
                }
            }
            // New students must complete school / district / grade onboarding.
            if role == .student {
                user.profileCompleted = false
            }
            saveSession(user: user, persist: true)
            Task.detached(priority: .utility) {
                await ContentLibrary.shared.refreshFromCloud()
            }
            return .success(())
        } catch {
            return .failure(mapRemoteError(error))
        }
    }

    private func registerLocal(
        name: String,
        email: String,
        password: String,
        role: UserRole,
        phone: String = ""
    ) -> Result<Void, AuthError> {
        var accounts = loadAccounts()
        guard !accounts.contains(where: { $0.email.lowercased() == email }) else {
            return .failure(.emailAlreadyRegistered)
        }
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let account = StoredAccount(
            id: UUID(),
            name: name,
            email: email,
            role: role,
            passwordHash: Self.hash(password: password),
            profileCompleted: role == .student ? false : true,
            phone: trimmedPhone.isEmpty ? nil : trimmedPhone,
            tutorApprovalStatus: role == .tutor ? TutorApprovalStatus.none.rawValue : nil
        )
        accounts.append(account)
        saveAccounts(accounts)
        saveSession(user: account.asUser, persist: true)
        return .success(())
    }

    func saveSessionFromExternal(user: User) {
        saveSession(user: user, persist: true)
    }

    // MARK: - Student profile (school / district / grade)

    /// Completes the post-signup welcome flow for students.
    func completeStudentProfile(
        school: String,
        schoolDistrict: String,
        grade: String
    ) async -> Result<Void, AuthError> {
        guard var user = currentUser, user.role == .student else {
            return .failure(.remote("Only students complete this step."))
        }

        let schoolName = school.trimmingCharacters(in: .whitespacesAndNewlines)
        let district = schoolDistrict.trimmingCharacters(in: .whitespacesAndNewlines)
        let gradeValue = grade.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !schoolName.isEmpty, !district.isEmpty, !gradeValue.isEmpty else {
            return .failure(.invalidCredentials)
        }

        if client.isConfigured {
            do {
                try await ensureValidCloudSession(forceRefresh: false)
                let update = ProfileStudentInfoUpdate(
                    school: schoolName,
                    schoolDistrict: district,
                    grade: gradeValue,
                    profileCompleted: true
                )
                try await client.update(
                    table: "profiles",
                    query: "id=eq.\(user.id.uuidString)",
                    values: update
                )
            } catch {
                return .failure(mapRemoteError(error))
            }
        } else {
            var accounts = loadAccounts()
            guard let index = accounts.firstIndex(where: { $0.id == user.id }) else {
                return .failure(.accountNotFound)
            }
            accounts[index].school = schoolName
            accounts[index].schoolDistrict = district
            accounts[index].grade = gradeValue
            accounts[index].profileCompleted = true
            saveAccounts(accounts)
        }

        user.school = schoolName
        user.schoolDistrict = district
        user.grade = gradeValue
        user.profileCompleted = true
        saveSession(user: user, persist: true)
        return .success(())
    }

    /// Updates only the student's form / grade (from Settings). Locks Home + Browse to this form.
    func updateStudentGrade(_ grade: String) async -> Result<Void, AuthError> {
        guard var user = currentUser, user.role == .student else {
            return .failure(.remote("Only students can change form."))
        }

        let gradeValue = grade.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gradeValue.isEmpty, Level(rawValue: gradeValue) != nil else {
            return .failure(.invalidCredentials)
        }

        if client.isConfigured {
            do {
                try await ensureValidCloudSession(forceRefresh: false)
                let update = ProfileGradeUpdate(grade: gradeValue)
                try await client.update(
                    table: "profiles",
                    query: "id=eq.\(user.id.uuidString)",
                    values: update
                )
            } catch {
                return .failure(mapRemoteError(error))
            }
        } else {
            var accounts = loadAccounts()
            guard let index = accounts.firstIndex(where: { $0.id == user.id }) else {
                return .failure(.accountNotFound)
            }
            accounts[index].grade = gradeValue
            saveAccounts(accounts)
        }

        user.grade = gradeValue
        saveSession(user: user, persist: true)
        return .success(())
    }

    /// All student profiles (for admin / staff review). Excludes removed accounts.
    func fetchStudentProfiles() async -> Result<[RemoteProfile], AuthError> {
        switch await fetchAllProfiles() {
        case .failure(let error):
            return .failure(error)
        case .success(let all):
            return .success(all.filter { $0.userRole == .student })
        }
    }

    /// All platform profiles for the super-admin dashboard (students, tutors, admins).
    func fetchAllProfiles() async -> Result<[RemoteProfile], AuthError> {
        if client.isConfigured {
            do {
                // Always refresh first so Super Admin / Students never open on a stale JWT.
                try await ensureValidCloudSession(forceRefresh: true)
                let rows: [RemoteProfile] = try await client.select(
                    table: "profiles",
                    query: "select=*&order=full_name.asc"
                )
                // Hide soft-removed from lists by default
                let visible = rows.filter { $0.isRemoved != true }
                return .success(visible)
            } catch let error as AuthError {
                return .failure(error)
            } catch {
                return .failure(mapRemoteError(error))
            }
        }

        let local = loadAccounts()
            .filter { $0.isRemoved != true }
            .map(\.asRemoteProfile)
            .sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
        return .success(local)
    }

    /// Ensures Supabase JWT is usable before sensitive admin API calls.
    /// - Parameter forceRefresh: when true, always exchanges the refresh token (dashboards).
    func ensureValidCloudSession(forceRefresh: Bool = false) async throws {
        guard client.isConfigured else { return }
        guard client.currentSession != nil else {
            throw AuthError.remote("You are not signed in. Log in again, then open this screen.")
        }
        do {
            if forceRefresh {
                _ = try await client.forceRefreshSession()
            } else {
                try await client.ensureFreshAccessToken()
            }
        } catch {
            throw mapRemoteError(error)
        }
    }

    /// Super-admin: block or unblock an account (cannot target self or other admins).
    /// When blocking, pass a clear reason the user will see on login.
    func setAccountBlocked(userId: UUID, blocked: Bool, reason: String? = nil) async -> Result<Void, AuthError> {
        guard currentUser?.isAdmin == true else {
            return .failure(.remote("Only super admins can block accounts."))
        }
        guard userId != currentUser?.id else {
            return .failure(.remote("You cannot block your own account."))
        }

        let trimmedReason = reason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if blocked && trimmedReason.isEmpty {
            return .failure(.remote("Please enter a reason for blocking this account."))
        }

        if client.isConfigured {
            do {
                let target: RemoteProfile = try await client.select(
                    table: "profiles",
                    query: "id=eq.\(userId.uuidString)&select=*",
                    single: true
                )
                if target.userRole == .admin {
                    return .failure(.remote("Admin accounts cannot be blocked here."))
                }
                try await client.update(
                    table: "profiles",
                    query: "id=eq.\(userId.uuidString)",
                    values: ProfileAdminStatusUpdate(
                        isBlocked: blocked,
                        isRemoved: nil,
                        role: nil,
                        tutorApprovalStatus: nil,
                        adminStatusReason: blocked ? trimmedReason : nil,
                        clearAdminStatusReason: !blocked
                    )
                )
                return .success(())
            } catch {
                return .failure(mapRemoteError(error))
            }
        }

        var accounts = loadAccounts()
        guard let index = accounts.firstIndex(where: { $0.id == userId }) else {
            return .failure(.accountNotFound)
        }
        if accounts[index].role == .admin {
            return .failure(.remote("Admin accounts cannot be blocked here."))
        }
        accounts[index].isBlocked = blocked
        accounts[index].adminStatusReason = blocked ? trimmedReason : nil
        saveAccounts(accounts)
        return .success(())
    }

    /// Tutor submits verification details after registration.
    func submitTutorApplication(
        phone: String,
        highestEducation: String,
        lastInstitution: String,
        gender: String,
        addressLocation: String,
        subjectMajor: String,
        referenceContacts: String
    ) async -> Result<Void, AuthError> {
        guard var user = currentUser, user.role == .tutor else {
            return .failure(.remote("Only tutor accounts submit this application."))
        }

        let fields = [
            phone, highestEducation, lastInstitution, gender,
            addressLocation, subjectMajor, referenceContacts
        ].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard fields.allSatisfy({ !$0.isEmpty }) else {
            return .failure(.invalidCredentials)
        }

        let update = ProfileTutorApplicationUpdate(
            phone: fields[0],
            highestEducation: fields[1],
            lastInstitution: fields[2],
            gender: fields[3],
            addressLocation: fields[4],
            subjectMajor: fields[5],
            referenceContacts: fields[6],
            tutorApprovalStatus: TutorApprovalStatus.pending.rawValue,
            adminStatusReason: ""
        )

        if client.isConfigured {
            do {
                try await ensureValidCloudSession(forceRefresh: false)
                try await client.update(
                    table: "profiles",
                    query: "id=eq.\(user.id.uuidString)",
                    values: update
                )
            } catch {
                return .failure(mapRemoteError(error))
            }
        } else {
            var accounts = loadAccounts()
            guard let index = accounts.firstIndex(where: { $0.id == user.id }) else {
                return .failure(.accountNotFound)
            }
            accounts[index].phone = update.phone
            accounts[index].highestEducation = update.highestEducation
            accounts[index].lastInstitution = update.lastInstitution
            accounts[index].gender = update.gender
            accounts[index].addressLocation = update.addressLocation
            accounts[index].subjectMajor = update.subjectMajor
            accounts[index].referenceContacts = update.referenceContacts
            accounts[index].tutorApprovalStatus = TutorApprovalStatus.pending.rawValue
            accounts[index].adminStatusReason = nil
            saveAccounts(accounts)
        }

        user.phone = update.phone
        user.highestEducation = update.highestEducation
        user.lastInstitution = update.lastInstitution
        user.gender = update.gender
        user.addressLocation = update.addressLocation
        user.subjectMajor = update.subjectMajor
        user.referenceContacts = update.referenceContacts
        user.tutorApprovalStatus = TutorApprovalStatus.pending.rawValue
        user.adminStatusReason = nil
        saveSession(user: user, persist: true)
        return .success(())
    }

    /// Rejected tutor chooses to edit details again (status → none).
    func beginTutorResubmit() async -> Result<Void, AuthError> {
        guard var user = currentUser, user.role == .tutor else {
            return .failure(.remote("Only tutors can resubmit."))
        }
        guard user.tutorApprovalStatus == TutorApprovalStatus.rejected.rawValue else {
            return .failure(.remote("Only rejected applications can be resubmitted this way."))
        }

        if client.isConfigured {
            do {
                try await client.update(
                    table: "profiles",
                    query: "id=eq.\(user.id.uuidString)",
                    values: ProfileAdminStatusUpdate(
                        isBlocked: nil,
                        isRemoved: nil,
                        role: nil,
                        tutorApprovalStatus: TutorApprovalStatus.none.rawValue,
                        adminStatusReason: nil,
                        clearAdminStatusReason: false
                    )
                )
            } catch {
                return .failure(mapRemoteError(error))
            }
        } else {
            var accounts = loadAccounts()
            guard let index = accounts.firstIndex(where: { $0.id == user.id }) else {
                return .failure(.accountNotFound)
            }
            accounts[index].tutorApprovalStatus = TutorApprovalStatus.none.rawValue
            saveAccounts(accounts)
        }

        user.tutorApprovalStatus = TutorApprovalStatus.none.rawValue
        saveSession(user: user, persist: true)
        return .success(())
    }

    /// Super admin approves or rejects a tutor application.
    /// Rejection requires a reason shown to the tutor when they log in.
    func setTutorApproval(userId: UUID, status: TutorApprovalStatus, reason: String? = nil) async -> Result<Void, AuthError> {
        guard currentUser?.isAdmin == true else {
            return .failure(.remote("Only super admins can approve tutors."))
        }
        guard status == .approved || status == .rejected else {
            return .failure(.remote("Invalid approval status."))
        }

        let trimmedReason = reason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if status == .rejected && trimmedReason.isEmpty {
            return .failure(.remote("Please enter a reason for rejecting this application."))
        }

        if client.isConfigured {
            do {
                let target: RemoteProfile = try await client.select(
                    table: "profiles",
                    query: "id=eq.\(userId.uuidString)&select=*",
                    single: true
                )
                guard target.userRole == .tutor else {
                    return .failure(.remote("This account is not a tutor."))
                }
                try await client.update(
                    table: "profiles",
                    query: "id=eq.\(userId.uuidString)",
                    values: ProfileAdminStatusUpdate(
                        isBlocked: nil,
                        isRemoved: nil,
                        role: nil,
                        tutorApprovalStatus: status.rawValue,
                        adminStatusReason: status == .rejected ? trimmedReason : nil,
                        clearAdminStatusReason: status == .approved
                    )
                )
                return .success(())
            } catch {
                return .failure(mapRemoteError(error))
            }
        }

        var accounts = loadAccounts()
        guard let index = accounts.firstIndex(where: { $0.id == userId }) else {
            return .failure(.accountNotFound)
        }
        guard accounts[index].role == .tutor else {
            return .failure(.remote("This account is not a tutor."))
        }
        accounts[index].tutorApprovalStatus = status.rawValue
        accounts[index].adminStatusReason = status == .rejected ? trimmedReason : nil
        saveAccounts(accounts)
        return .success(())
    }

    /// Tutor requests admin approval to manage additional subject(s).
    /// Majors set at application are locked; only super admin can grant extras.
    func requestExtraSubject(_ subjectName: String) async -> Result<Void, AuthError> {
        await requestExtraSubjects([subjectName])
    }

    /// Request one or more subjects (admin must approve before they appear on the dashboard).
    func requestExtraSubjects(_ subjectNames: [String]) async -> Result<Void, AuthError> {
        guard var user = currentUser, user.role == .tutor else {
            return .failure(.remote("Only tutors can request extra subjects."))
        }
        guard user.tutorStatus == .approved else {
            return .failure(.remote("Your tutor account must be approved first."))
        }

        let managedKeys = Set(user.managedSubjectNames.map { $0.lowercased() })
        var seen = Set<String>()
        var unique: [String] = []
        for raw in subjectNames {
            let name = User.canonicalizeSubjectName(raw)
            guard !name.isEmpty else { continue }
            let key = name.lowercased()
            guard !managedKeys.contains(key) else { continue }
            if seen.insert(key).inserted {
                unique.append(name)
            }
        }
        guard !unique.isEmpty else {
            return .failure(.remote("Pick at least one subject you don’t already manage."))
        }

        // Merge with any existing pending request so tutors can add more before admin acts.
        var pending = User.parseSubjectList(user.pendingSubjectRequest)
        for name in unique {
            if !pending.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                pending.append(name)
            }
        }
        let clean = pending.joined(separator: ", ")

        if client.isConfigured {
            do {
                try await ensureValidCloudSession(forceRefresh: false)
                try await client.update(
                    table: "profiles",
                    query: "id=eq.\(user.id.uuidString)",
                    values: ProfileAdminStatusUpdate(pendingSubjectRequest: clean)
                )
            } catch {
                return .failure(mapRemoteError(error))
            }
        } else {
            var accounts = loadAccounts()
            guard let index = accounts.firstIndex(where: { $0.id == user.id }) else {
                return .failure(.accountNotFound)
            }
            accounts[index].pendingSubjectRequest = clean
            saveAccounts(accounts)
        }
        user.pendingSubjectRequest = clean
        saveSession(user: user, persist: true)
        return .success(())
    }

    /// Tutor withdraws a pending subject-access request.
    func cancelPendingSubjectRequest() async -> Result<Void, AuthError> {
        guard var user = currentUser, user.role == .tutor else {
            return .failure(.remote("Only tutors can cancel subject requests."))
        }
        let pending = user.pendingSubjectRequest?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !pending.isEmpty else { return .success(()) }

        if client.isConfigured {
            do {
                try await ensureValidCloudSession(forceRefresh: false)
                try await client.update(
                    table: "profiles",
                    query: "id=eq.\(user.id.uuidString)",
                    values: ProfileAdminStatusUpdate(
                        pendingSubjectRequest: nil,
                        clearPendingSubjectRequest: true
                    )
                )
            } catch {
                return .failure(mapRemoteError(error))
            }
        } else {
            var accounts = loadAccounts()
            guard let index = accounts.firstIndex(where: { $0.id == user.id }) else {
                return .failure(.accountNotFound)
            }
            accounts[index].pendingSubjectRequest = nil
            saveAccounts(accounts)
        }
        user.pendingSubjectRequest = nil
        saveSession(user: user, persist: true)
        return .success(())
    }

    /// Super admin grants or denies an extra-subject request (supports comma-separated lists).
    func resolveExtraSubjectRequest(userId: UUID, approve: Bool) async -> Result<Void, AuthError> {
        guard currentUser?.isAdmin == true else {
            return .failure(.remote("Only super admins can approve subject access."))
        }

        if client.isConfigured {
            do {
                let target: RemoteProfile = try await client.select(
                    table: "profiles",
                    query: "id=eq.\(userId.uuidString)&select=*",
                    single: true
                )
                let requested = target.pendingSubjectRequest?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !requested.isEmpty else {
                    return .failure(.remote("No pending subject request."))
                }
                let requestedList = User.parseSubjectList(requested)
                var extras = User.parseSubjectList(target.allowedExtraSubjects)
                if approve {
                    for name in requestedList {
                        if !extras.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                            extras.append(name)
                        }
                    }
                }
                try await client.update(
                    table: "profiles",
                    query: "id=eq.\(userId.uuidString)",
                    values: ProfileAdminStatusUpdate(
                        allowedExtraSubjects: extras.joined(separator: ", "),
                        pendingSubjectRequest: nil,
                        clearPendingSubjectRequest: true
                    )
                )
                return .success(())
            } catch {
                return .failure(mapRemoteError(error))
            }
        }

        var accounts = loadAccounts()
        guard let index = accounts.firstIndex(where: { $0.id == userId }) else {
            return .failure(.accountNotFound)
        }
        let requested = accounts[index].pendingSubjectRequest?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !requested.isEmpty else {
            return .failure(.remote("No pending subject request."))
        }
        if approve {
            var extras = User.parseSubjectList(accounts[index].allowedExtraSubjects)
            for name in User.parseSubjectList(requested) {
                if !extras.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                    extras.append(name)
                }
            }
            accounts[index].allowedExtraSubjects = extras.joined(separator: ", ")
        }
        accounts[index].pendingSubjectRequest = nil
        saveAccounts(accounts)
        return .success(())
    }

    /// Runs only while the app is active; the root view cancels it on logout/backgrounding.
    func monitorAccountAccess() async {
        while !Task.isCancelled, isLoggedIn {
            await refreshCurrentUserProfile()
            guard !Task.isCancelled, isLoggedIn else { return }
            do {
                try await Task.sleep(nanoseconds: 5_000_000_000)
            } catch { return }
        }
    }

    /// Pull latest profile for the signed-in user, including administrative restrictions.
    func refreshCurrentUserProfile() async {
        guard let user = currentUser else { return }
        let generation = authGeneration
        if client.isConfigured {
            do {
                try await ensureValidCloudSession(forceRefresh: false)
                let profiles: [RemoteProfile] = try await client.select(
                    table: "profiles",
                    query: "id=eq.\(user.id.uuidString)&select=*"
                )
                guard !Task.isCancelled, generation == authGeneration,
                      currentUser?.id == user.id else { return }
                guard let profile = profiles.first else {
                    signOutForAccountRestriction("Your account is no longer available. Contact Tricon Academy for help.")
                    return
                }
                if let message = accessDeniedMessage(for: profile) {
                    signOutForAccountRestriction(message)
                    return
                }
                // Refresh visible details without changing the user's Remember me choice.
                let remember = readFromKeychain(key: sessionKeychainKey) != nil
                saveSession(user: profile.asUser, persist: remember)
            } catch {
                // A connection failure is not evidence that an account was blocked.
            }
        } else if let account = loadAccounts().first(where: { $0.id == user.id }) {
            if let message = accessDeniedMessage(for: account.asRemoteProfile) {
                signOutForAccountRestriction(message)
                return
            }
            let remember = readFromKeychain(key: sessionKeychainKey) != nil
            saveSession(user: account.asUser, persist: remember)
        }
    }

    private func signOutForAccountRestriction(_ message: String) {
        // Clear credentials synchronously so an old request cannot sign the user back in.
        client.clearSession()
        clearLocalLoginState()
        needsPasswordResetCompletion = false
        deepLinkError = nil
        accountAccessMessage = message + "\n\nYou have been signed out."
    }

    /// Super-admin: strip tutor privileges (role → student).
    func revokeTutorAccess(userId: UUID) async -> Result<Void, AuthError> {
        guard currentUser?.isAdmin == true else {
            return .failure(.remote("Only super admins can change tutor access."))
        }
        guard userId != currentUser?.id else {
            return .failure(.remote("You cannot change your own role here."))
        }

        if client.isConfigured {
            do {
                let target: RemoteProfile = try await client.select(
                    table: "profiles",
                    query: "id=eq.\(userId.uuidString)&select=*",
                    single: true
                )
                guard target.userRole == .tutor else {
                    return .failure(.remote("This account is not a tutor."))
                }
                try await client.update(
                    table: "profiles",
                    query: "id=eq.\(userId.uuidString)",
                    values: ProfileAdminStatusUpdate(
                        isBlocked: nil,
                        isRemoved: nil,
                        role: UserRole.student.rawValue,
                        tutorApprovalStatus: TutorApprovalStatus.none.rawValue
                    )
                )
                return .success(())
            } catch {
                return .failure(mapRemoteError(error))
            }
        }

        var accounts = loadAccounts()
        guard let index = accounts.firstIndex(where: { $0.id == userId }) else {
            return .failure(.accountNotFound)
        }
        guard accounts[index].role == .tutor else {
            return .failure(.remote("This account is not a tutor."))
        }
        accounts[index].role = .student
        accounts[index].tutorApprovalStatus = TutorApprovalStatus.none.rawValue
        saveAccounts(accounts)
        return .success(())
    }

    /// Super-admin: permanently remove access (soft-delete). Account cannot sign in.
    func removeAccount(userId: UUID) async -> Result<Void, AuthError> {
        guard currentUser?.isAdmin == true else {
            return .failure(.remote("Only super admins can remove accounts."))
        }
        guard userId != currentUser?.id else {
            return .failure(.remote("You cannot remove your own account."))
        }

        if client.isConfigured {
            do {
                let target: RemoteProfile = try await client.select(
                    table: "profiles",
                    query: "id=eq.\(userId.uuidString)&select=*",
                    single: true
                )
                if target.userRole == .admin {
                    return .failure(.remote("Admin accounts cannot be removed here."))
                }
                try await client.update(
                    table: "profiles",
                    query: "id=eq.\(userId.uuidString)",
                    values: ProfileAdminStatusUpdate(
                        isBlocked: true,
                        isRemoved: true,
                        role: nil,
                        tutorApprovalStatus: nil,
                        adminStatusReason: "Account removed by super admin.",
                        clearAdminStatusReason: false
                    )
                )
                return .success(())
            } catch {
                return .failure(mapRemoteError(error))
            }
        }

        var accounts = loadAccounts()
        guard let index = accounts.firstIndex(where: { $0.id == userId }) else {
            return .failure(.accountNotFound)
        }
        if accounts[index].role == .admin {
            return .failure(.remote("Admin accounts cannot be removed here."))
        }
        accounts[index].isBlocked = true
        accounts[index].isRemoved = true
        accounts[index].adminStatusReason = "Account removed by super admin."
        saveAccounts(accounts)
        return .success(())
    }

    // MARK: - Password reset

    /// Local: updates password on device. Cloud: sends Supabase recovery email (newPassword ignored).
    func resetPassword(email: String, newPassword: String) async -> Result<Void, AuthError> {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty else {
            return .failure(.invalidCredentials)
        }

        if client.isConfigured {
            do {
                try await client.recoverPassword(email: normalizedEmail)
                return .success(())
            } catch {
                return .failure(mapRemoteError(error))
            }
        }

        guard newPassword.count >= 6 else {
            return .failure(.invalidCredentials)
        }
        var accounts = loadAccounts()
        guard let index = accounts.firstIndex(where: { $0.email.lowercased() == normalizedEmail }) else {
            return .failure(.accountNotFound)
        }
        accounts[index].passwordHash = Self.hash(password: newPassword)
        saveAccounts(accounts)
        return .success(())
    }

    func logout() {
        currentUser = nil
        isLoggedIn = false
        needsPasswordResetCompletion = false
        deepLinkError = nil
        deleteFromKeychain(key: sessionKeychainKey)
        Task {
            await client.signOut()
        }
    }

    static func displayName(for role: UserRole, fallback: String) -> String {
        switch role {
        case .admin: return fallback.isEmpty ? "Admin" : fallback
        case .tutor: return fallback.isEmpty ? "Tutor" : fallback
        case .student: return fallback.isEmpty ? "Student" : fallback
        }
    }

    // MARK: - Profiles

    private func fetchOrCreateProfile(
        userId: UUID,
        email: String,
        fallbackName: String,
        role: UserRole,
        phone: String? = nil
    ) async throws -> RemoteProfile {
        do {
            return try await client.select(
                table: "profiles",
                query: "id=eq.\(userId.uuidString)&select=*",
                single: true
            )
        } catch {
            // Only create a profile when the row is missing (PostgREST 406 / "0 rows").
            // Other failures (network, RLS, 5xx) must surface so we don't invent data.
            let text = ((error as? LocalizedError)?.errorDescription ?? error.localizedDescription).lowercased()
            let looksMissing =
                text.contains("0 rows")
                || text.contains("no rows")
                || text.contains("multiple (or no) rows")
                || text.contains("pgrst116")
                || text.contains("(406)")
            guard looksMissing else { throw error }

            let insert = ProfileInsert(
                id: userId,
                fullName: fallbackName,
                email: email,
                role: role.rawValue,
                phone: phone,
                profileCompleted: role == .student ? false : true,
                tutorApprovalStatus: role == .tutor ? TutorApprovalStatus.none.rawValue : nil
            )
            return try await client.insert(table: "profiles", row: insert)
        }
    }

    private func mapRemoteError(_ error: Error) -> AuthError {
        let text = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let lower = text.lowercased()
        if lower.contains("invalid login") || lower.contains("invalid credentials") {
            return .invalidCredentials
        }
        if lower.contains("already registered") || lower.contains("user already") {
            return .emailAlreadyRegistered
        }
        if lower.contains("email not confirmed") {
            return .remote("Confirm your email from the link Supabase sent, then try again. (Disable “Confirm email” under Auth → Providers for easier testing.)")
        }
        if lower.contains("jwt expired")
            || lower.contains("invalid jwt")
            || lower.contains("session expired")
            || lower.contains("log out and log in")
            || lower.contains("refresh_token")
            || lower.contains("invalid refresh")
            || lower.contains("not authenticated")
            || lower.contains("you are not signed in") {
            return .remote("Your session expired. Log out, log in again, then open Students or Super Admin.")
        }
        return .remote(text)
    }

    private static func hash(password: String) -> String {
        let digest = SHA256.hash(data: Data(password.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func loadAccounts() -> [StoredAccount] {
        guard let data = readFromKeychain(key: accountsKeychainKey),
              let accounts = try? JSONDecoder().decode([StoredAccount].self, from: data) else {
            return []
        }
        return accounts
    }

    private func saveAccounts(_ accounts: [StoredAccount]) {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        saveToKeychain(data: data, key: accountsKeychainKey)
    }

    private func saveSession(user: User, persist: Bool) {
        currentUser = user
        isLoggedIn = true
        if persist {
            if let data = try? JSONEncoder().encode(user) {
                saveToKeychain(data: data, key: sessionKeychainKey)
            }
        } else {
            deleteFromKeychain(key: sessionKeychainKey)
        }
    }

    private func restoreSession() async {
        if client.isConfigured, let cloudSession = client.currentSession {
            // Open remembered accounts immediately so downloaded lessons remain reachable
            // offline. Only restore the profile belonging to this persisted session.
            if let data = readFromKeychain(key: sessionKeychainKey),
               let user = try? JSONDecoder().decode(User.self, from: data),
               user.id == cloudSession.user.id {
                currentUser = user
                isLoggedIn = true
            }
            let generation = authGeneration
            do {
                // Access tokens expire (~1h). Refresh before any profile call so cold
                // launches don't leave the user "logged in" with a dead JWT.
                try await client.ensureFreshAccessToken()
                guard let session = client.currentSession else {
                    clearLocalLoginState()
                    return
                }
                let profile = try await fetchOrCreateProfile(
                    userId: session.user.id,
                    email: session.user.email ?? "",
                    fallbackName: session.user.email?.components(separatedBy: "@").first ?? "User",
                    role: .student
                )
                guard generation == authGeneration else { return }
                if let message = accessDeniedMessage(for: profile) {
                    signOutForAccountRestriction(message)
                    return
                }
                saveSession(user: profile.asUser, persist: true)
                Task.detached(priority: .utility) {
                    await ContentLibrary.shared.refreshFromCloud()
                }
                return
            } catch {
                guard generation == authGeneration else { return }
                // Auth-hard failures → force re-login. Transient network → keep cached user
                // and let the next API call refresh again.
                if isHardAuthFailure(error) {
                    client.clearSession()
                    clearLocalLoginState()
                    return
                }
                if let data = readFromKeychain(key: sessionKeychainKey),
                   let user = try? JSONDecoder().decode(User.self, from: data),
                   user.id == client.currentSession?.user.id {
                    currentUser = user
                    isLoggedIn = true
                }
                return
            }
        }

        if let data = readFromKeychain(key: sessionKeychainKey),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            // Local mode: re-check block/remove flags on stored accounts.
            if !client.isConfigured {
                if let account = loadAccounts().first(where: { $0.id == user.id }),
                   let message = accessDeniedMessage(for: account.asRemoteProfile) {
                    signOutForAccountRestriction(message)
                    return
                }
                currentUser = user
                isLoggedIn = true
                return
            }
            // Cloud mode without a live Supabase session → require login again.
            clearLocalLoginState()
        }
    }

    private func clearLocalLoginState() {
        deleteFromKeychain(key: sessionKeychainKey)
        currentUser = nil
        isLoggedIn = false
    }

    private func isHardAuthFailure(_ error: Error) -> Bool {
        let text = ((error as? LocalizedError)?.errorDescription ?? error.localizedDescription).lowercased()
        return text.contains("jwt expired")
            || text.contains("invalid jwt")
            || text.contains("invalid refresh")
            || text.contains("refresh_token")
            || text.contains("session not found")
            || text.contains("not signed in")
            || text.contains("no session")
            || text.contains("log out and log in")
    }

    private func saveToKeychain(data: Data, key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var newItem = query
        newItem[kSecValueData as String] = data
        SecItemAdd(newItem as CFDictionary, nil)
    }

    private func readFromKeychain(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
