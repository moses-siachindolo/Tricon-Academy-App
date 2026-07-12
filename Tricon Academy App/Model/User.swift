import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    var name: String
    var email: String
    var role: UserRole

    // Compatibility properties for existing views (e.g. HomeView)
    var fullName: String {
        name
    }

    /// Platform administrator (highest privileges).
    var isAdmin: Bool {
        role == .admin
    }

    /// Subject tutor / teacher account.
    var isTutor: Bool {
        role == .tutor
    }

    /// Student learner account.
    var isStudent: Bool {
        role == .student
    }

    /// Admin and tutors can upload documents, lessons, and manage content.
    var canManageContent: Bool {
        role.canManageContent
    }

    var roleDisplayName: String {
        role.displayName
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

    /// Content management (upload documents, lessons, etc.)
    var canManageContent: Bool {
        switch self {
        case .admin, .tutor: return true
        case .student: return false
        }
    }

    /// Roles offered during registration (admin is reserved for known accounts).
    static var registrableRoles: [UserRole] {
        [.student, .tutor]
    }
}
