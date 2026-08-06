import Foundation

/// Tutor application lifecycle. New tutors start at `.none`, submit to `.pending`,
/// then a super admin sets `.approved` or `.rejected`.
enum TutorApprovalStatus: String, Codable, CaseIterable {
    case none
    case pending
    case approved
    case rejected

    var displayName: String {
        switch self {
        case .none: return "Not submitted"
        case .pending: return "Pending approval"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        }
    }
}

struct User: Codable, Identifiable {
    let id: UUID
    var name: String
    var email: String
    var role: UserRole
    /// School name (students).
    var school: String?
    /// District of the school (students).
    var schoolDistrict: String?
    /// Current form / grade, e.g. "Form 1" (students).
    var grade: String?
    /// Student finished the post-signup welcome profile step.
    var profileCompleted: Bool?
    var phone: String?
    /// Super-admin note for block/remove (shown on login when blocked).
    var adminStatusReason: String?

    // Kept for decoding older sessions / remote profiles (ignored by app logic).
    var highestEducation: String?
    var lastInstitution: String?
    var gender: String?
    var addressLocation: String?
    var subjectMajor: String?
    var referenceContacts: String?
    var tutorApprovalStatus: String?
    var allowedExtraSubjects: String?
    var pendingSubjectRequest: String?

    var fullName: String { name }

    var isAdmin: Bool { role == .admin }
    var isTutor: Bool { role == .tutor }
    var isStudent: Bool { role == .student }

    /// Staff tools (Manage tab, uploads). Admins always; tutors only after approval.
    var canManageContent: Bool {
        switch role {
        case .admin:
            return true
        case .tutor:
            return tutorStatus == .approved
        case .student:
            return false
        }
    }

    var roleDisplayName: String { role.displayName }

    /// Normalized tutor approval. Legacy tutors with a blank status keep access (approved).
    /// New registrations always write an explicit `"none"` so they must complete verification.
    var tutorStatus: TutorApprovalStatus {
        guard role == .tutor else { return .none }
        let raw = tutorApprovalStatus?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty { return .approved }
        return TutorApprovalStatus(rawValue: raw) ?? .none
    }

    /// Tutor must fill the verification form before using the app.
    var needsTutorApplication: Bool {
        guard role == .tutor else { return false }
        return tutorStatus == .none
    }

    /// Application submitted; waiting for super-admin decision.
    var isAwaitingTutorApproval: Bool {
        guard role == .tutor else { return false }
        return tutorStatus == .pending
    }

    /// Super admin rejected the application.
    var isTutorRejected: Bool {
        guard role == .tutor else { return false }
        return tutorStatus == .rejected
    }

    // MARK: - Tutor subject specialism (upload / delete only)

    /// Catalogue subject names this user may **upload, create folders for, or delete**.
    /// Admins: every subject. Tutors: `subjectMajor` + approved `allowedExtraSubjects`.
    /// Students: none. Viewing all subjects stays open for everyone.
    var managedSubjectNames: [String] {
        switch role {
        case .admin:
            return Self.catalogueSubjectNames
        case .tutor:
            let majors = Self.parseSubjectList(subjectMajor)
            let extras = Self.parseSubjectList(allowedExtraSubjects)
            // De-dupe while preserving order
            var seen = Set<String>()
            var result: [String] = []
            for name in majors + extras {
                let key = name.lowercased()
                if seen.insert(key).inserted {
                    result.append(name)
                }
            }
            return result
        case .student:
            return []
        }
    }

    /// Human-readable list for UI (“Mathematics · Physics”).
    var managedSubjectsDisplay: String {
        let names = managedSubjectNames
        if names.isEmpty {
            return isTutor ? "Not set — complete your specialist subjects" : "All subjects"
        }
        return names.joined(separator: " · ")
    }

    /// Whether this staff user can upload/delete/organise content for a subject.
    /// Everyone may still **view** any subject. Unapproved tutors cannot manage.
    func canManageSubject(_ subjectName: String) -> Bool {
        switch role {
        case .admin:
            return true
        case .student:
            return false
        case .tutor:
            guard tutorStatus == .approved else { return false }
            let managed = managedSubjectNames
            // No specialism on file → cannot manage (view only) until they set it.
            guard !managed.isEmpty else { return false }
            return managed.contains { Self.subjectsMatch($0, subjectName) }
        }
    }

    /// All core + optional subject names used by the app catalogue.
    static var catalogueSubjectNames: [String] {
        allSubjects.filter { $0.name != "Optionals" }.map(\.name) + optionalSubjects.map(\.name)
    }

    /// Split free-text majors like "Math and Physics", "Mathematics, Chemistry".
    static func parseSubjectList(_ raw: String?) -> [String] {
        guard let raw else { return [] }
        let cleaned = raw
            .replacingOccurrences(of: " and ", with: ",", options: .caseInsensitive)
            .replacingOccurrences(of: "&", with: ",")
            .replacingOccurrences(of: "/", with: ",")
            .replacingOccurrences(of: ";", with: ",")
        return cleaned
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { canonicalizeSubjectName($0) }
    }

    /// Map common tutor shorthand onto catalogue names.
    static func canonicalizeSubjectName(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let aliases: [String: String] = [
            "math": "Mathematics",
            "maths": "Mathematics",
            "mathematics": "Mathematics",
            "physics": "Physics",
            "chem": "Chemistry",
            "chemistry": "Chemistry",
            "bio": "Biology",
            "biology": "Biology",
            "english": "English",
            "eng": "English",
            "civic": "Civic Education",
            "civics": "Civic Education",
            "civic education": "Civic Education",
            "accounts": "Accounts",
            "account": "Accounts",
            "accounting": "Accounts",
            "re": "Religious Education",
            "religious": "Religious Education",
            "religious education": "Religious Education",
            "computer science": "Computer Science",
            "cs": "Computer Science",
            "computers": "Computer Science",
            "ict": "Computer Science"
        ]
        if let mapped = aliases[lower] { return mapped }
        // Exact catalogue match (case-insensitive)
        if let match = catalogueSubjectNames.first(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return match
        }
        return trimmed
    }

    static func subjectsMatch(_ a: String, _ b: String) -> Bool {
        canonicalizeSubjectName(a).caseInsensitiveCompare(canonicalizeSubjectName(b)) == .orderedSame
    }

    /// Students must complete school / district / grade after registering.
    var needsStudentOnboarding: Bool {
        guard role == .student else { return false }
        if profileCompleted == true { return false }
        let schoolOk = !(school?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let districtOk = !(schoolDistrict?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let gradeOk = !(grade?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return !(schoolOk && districtOk && gradeOk)
    }

    init(
        id: UUID,
        name: String,
        email: String,
        role: UserRole,
        school: String? = nil,
        schoolDistrict: String? = nil,
        grade: String? = nil,
        profileCompleted: Bool? = nil,
        phone: String? = nil,
        adminStatusReason: String? = nil,
        highestEducation: String? = nil,
        lastInstitution: String? = nil,
        gender: String? = nil,
        addressLocation: String? = nil,
        subjectMajor: String? = nil,
        referenceContacts: String? = nil,
        tutorApprovalStatus: String? = nil,
        allowedExtraSubjects: String? = nil,
        pendingSubjectRequest: String? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        self.school = school
        self.schoolDistrict = schoolDistrict
        self.grade = grade
        self.profileCompleted = profileCompleted
        self.phone = phone
        self.adminStatusReason = adminStatusReason
        self.highestEducation = highestEducation
        self.lastInstitution = lastInstitution
        self.gender = gender
        self.addressLocation = addressLocation
        self.subjectMajor = subjectMajor
        self.referenceContacts = referenceContacts
        self.tutorApprovalStatus = tutorApprovalStatus
        self.allowedExtraSubjects = allowedExtraSubjects
        self.pendingSubjectRequest = pendingSubjectRequest
    }
}

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case student
    case tutor
    case admin

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .student: return "Student"
        case .tutor: return "Tutor"
        case .admin: return "Admin"
        }
    }

    var canManageContent: Bool {
        switch self {
        case .admin, .tutor: return true
        case .student: return false
        }
    }

    static var registrableRoles: [UserRole] {
        [.student, .tutor]
    }
}
