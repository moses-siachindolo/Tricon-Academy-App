import Foundation

// MARK: - profiles

struct RemoteProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var fullName: String
    var email: String
    var role: String
    var phone: String?
    var school: String?
    var schoolDistrict: String?
    var grade: String?
    var profileCompleted: Bool?
    var isBlocked: Bool?
    var isRemoved: Bool?
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
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case role
        case phone
        case school
        case schoolDistrict = "school_district"
        case grade
        case profileCompleted = "profile_completed"
        case isBlocked = "is_blocked"
        case isRemoved = "is_removed"
        case highestEducation = "highest_education"
        case lastInstitution = "last_institution"
        case gender
        case addressLocation = "address_location"
        case subjectMajor = "subject_major"
        case referenceContacts = "reference_contacts"
        case tutorApprovalStatus = "tutor_approval_status"
        case adminStatusReason = "admin_status_reason"
        case allowedExtraSubjects = "allowed_extra_subjects"
        case pendingSubjectRequest = "pending_subject_request"
        case createdAt = "created_at"
    }

    var userRole: UserRole {
        UserRole(rawValue: role) ?? .student
    }

    var tutorStatus: TutorApprovalStatus {
        guard let raw = tutorApprovalStatus?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return userRole == .tutor ? .approved : .none
        }
        return TutorApprovalStatus(rawValue: raw) ?? .none
    }

    var isAccountBlocked: Bool {
        isBlocked == true
    }

    var isAccountRemoved: Bool {
        isRemoved == true
    }

    /// Cannot sign in when blocked or removed.
    var isAccessDenied: Bool {
        isAccountBlocked || isAccountRemoved
    }

    var asUser: User {
        User(
            id: id,
            name: fullName,
            email: email,
            role: userRole,
            school: school,
            schoolDistrict: schoolDistrict,
            grade: grade,
            profileCompleted: profileCompleted,
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
}

/// PATCH body for admin actions — only non-nil fields are sent.
struct ProfileAdminStatusUpdate: Encodable {
    var isBlocked: Bool?
    var isRemoved: Bool?
    var role: String?
    var tutorApprovalStatus: String?
    var adminStatusReason: String?
    /// When true, writes empty string to clear the reason (e.g. after approve).
    var clearAdminStatusReason: Bool = false

    enum CodingKeys: String, CodingKey {
        case isBlocked = "is_blocked"
        case isRemoved = "is_removed"
        case role
        case tutorApprovalStatus = "tutor_approval_status"
        case adminStatusReason = "admin_status_reason"
        case allowedExtraSubjects = "allowed_extra_subjects"
        case pendingSubjectRequest = "pending_subject_request"
    }

    var allowedExtraSubjects: String?
    var pendingSubjectRequest: String?
    var clearPendingSubjectRequest: Bool = false

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let isBlocked { try container.encode(isBlocked, forKey: .isBlocked) }
        if let isRemoved { try container.encode(isRemoved, forKey: .isRemoved) }
        if let role { try container.encode(role, forKey: .role) }
        if let tutorApprovalStatus { try container.encode(tutorApprovalStatus, forKey: .tutorApprovalStatus) }
        if clearAdminStatusReason {
            try container.encode("", forKey: .adminStatusReason)
        } else if let adminStatusReason {
            try container.encode(adminStatusReason, forKey: .adminStatusReason)
        }
        if let allowedExtraSubjects { try container.encode(allowedExtraSubjects, forKey: .allowedExtraSubjects) }
        if clearPendingSubjectRequest {
            try container.encode("", forKey: .pendingSubjectRequest)
        } else if let pendingSubjectRequest {
            try container.encode(pendingSubjectRequest, forKey: .pendingSubjectRequest)
        }
    }
}

struct ProfileInsert: Encodable {
    let id: UUID
    let fullName: String
    let email: String
    let role: String
    let phone: String?
    var school: String? = nil
    var schoolDistrict: String? = nil
    var grade: String? = nil
    var profileCompleted: Bool? = false
    var tutorApprovalStatus: String? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case role
        case phone
        case school
        case schoolDistrict = "school_district"
        case grade
        case profileCompleted = "profile_completed"
        case tutorApprovalStatus = "tutor_approval_status"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fullName, forKey: .fullName)
        try container.encode(email, forKey: .email)
        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encodeIfPresent(school, forKey: .school)
        try container.encodeIfPresent(schoolDistrict, forKey: .schoolDistrict)
        try container.encodeIfPresent(grade, forKey: .grade)
        try container.encodeIfPresent(profileCompleted, forKey: .profileCompleted)
        try container.encodeIfPresent(tutorApprovalStatus, forKey: .tutorApprovalStatus)
    }
}

struct ProfileTutorApplicationUpdate: Encodable {
    let phone: String
    let highestEducation: String
    let lastInstitution: String
    let gender: String
    let addressLocation: String
    let subjectMajor: String
    let referenceContacts: String
    let tutorApprovalStatus: String
    let adminStatusReason: String

    enum CodingKeys: String, CodingKey {
        case phone
        case highestEducation = "highest_education"
        case lastInstitution = "last_institution"
        case gender
        case addressLocation = "address_location"
        case subjectMajor = "subject_major"
        case referenceContacts = "reference_contacts"
        case tutorApprovalStatus = "tutor_approval_status"
        case adminStatusReason = "admin_status_reason"
    }
}

struct ProfileStudentInfoUpdate: Encodable {
    let school: String
    let schoolDistrict: String
    let grade: String
    let profileCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case school
        case schoolDistrict = "school_district"
        case grade
        case profileCompleted = "profile_completed"
    }
}

// MARK: - content_folders

struct RemoteFolder: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var section: String
    var levelRaw: String
    var subjectName: String
    var createdBy: UUID?
    var parentFolderId: UUID?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case section
        case levelRaw = "level_raw"
        case subjectName = "subject_name"
        case createdBy = "created_by"
        case parentFolderId = "parent_folder_id"
        case createdAt = "created_at"
    }

    /// Tolerant decode so a missing/partial column can never crash content browse.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Folder"
        section = (try? c.decodeIfPresent(String.self, forKey: .section)) ?? ContentSection.papers.rawValue
        levelRaw = (try? c.decodeIfPresent(String.self, forKey: .levelRaw)) ?? Level.form1.rawValue
        subjectName = (try? c.decodeIfPresent(String.self, forKey: .subjectName)) ?? ""
        createdBy = try? c.decodeIfPresent(UUID.self, forKey: .createdBy)
        parentFolderId = try? c.decodeIfPresent(UUID.self, forKey: .parentFolderId)
        createdAt = try? c.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    var asContentFolder: ContentFolder {
        ContentFolder(
            id: id,
            name: name,
            section: ContentSection(rawValue: section) ?? .papers,
            levelRaw: levelRaw,
            subjectName: subjectName,
            createdAt: createdAt ?? Date(),
            parentFolderId: parentFolderId
        )
    }
}

struct FolderInsert: Encodable {
    let id: UUID
    let name: String
    let section: String
    let levelRaw: String
    let subjectName: String
    let createdBy: UUID?
    let parentFolderId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case section
        case levelRaw = "level_raw"
        case subjectName = "subject_name"
        case createdBy = "created_by"
        case parentFolderId = "parent_folder_id"
    }
}

// MARK: - library_items

struct RemoteLibraryItem: Codable, Identifiable, Equatable {
    let id: UUID
    var kind: String
    var title: String
    var topic: String
    var description: String
    var levelRaw: String
    var subjectName: String
    var storagePath: String?
    var originalFileName: String
    var folderId: UUID?
    var uploaderId: UUID?
    var uploaderName: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
        case topic
        case description
        case levelRaw = "level_raw"
        case subjectName = "subject_name"
        case storagePath = "storage_path"
        case originalFileName = "original_file_name"
        case folderId = "folder_id"
        case uploaderId = "uploader_id"
        case uploaderName = "uploader_name"
        case createdAt = "created_at"
    }

    /// Tolerant decode so cloud rows with null/missing fields never crash the app.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = (try? c.decodeIfPresent(String.self, forKey: .kind)) ?? "paper"
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? "Untitled"
        topic = (try? c.decodeIfPresent(String.self, forKey: .topic)) ?? ""
        description = (try? c.decodeIfPresent(String.self, forKey: .description)) ?? ""
        levelRaw = (try? c.decodeIfPresent(String.self, forKey: .levelRaw)) ?? Level.form1.rawValue
        subjectName = (try? c.decodeIfPresent(String.self, forKey: .subjectName)) ?? ""
        storagePath = try? c.decodeIfPresent(String.self, forKey: .storagePath)
        originalFileName = (try? c.decodeIfPresent(String.self, forKey: .originalFileName)) ?? ""
        folderId = try? c.decodeIfPresent(UUID.self, forKey: .folderId)
        uploaderId = try? c.decodeIfPresent(UUID.self, forKey: .uploaderId)
        uploaderName = (try? c.decodeIfPresent(String.self, forKey: .uploaderName)) ?? "Staff"
        createdAt = try? c.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    var asLibraryItem: LibraryItem {
        let localOrRemote: String
        if let storagePath, !storagePath.isEmpty,
           let url = SupabaseClient.shared.publicURL(bucket: SupabaseConfig.contentBucket, path: storagePath) {
            localOrRemote = url.absoluteString
        } else {
            localOrRemote = ""
        }

        let mappedKind: LibraryContentKind
        switch kind {
        case "note": mappedKind = .note
        case "video": mappedKind = .video
        case "paper": mappedKind = .paper
        default: mappedKind = .paper
        }

        return LibraryItem(
            id: id,
            kind: mappedKind,
            title: title,
            topic: topic,
            description: description,
            levelRaw: levelRaw,
            subjectName: subjectName,
            localFilePath: localOrRemote,
            originalFileName: originalFileName,
            createdAt: createdAt ?? Date(),
            uploaderName: uploaderName,
            folderId: folderId
        )
    }
}

struct LibraryItemInsert: Encodable {
    let id: UUID
    let kind: String
    let title: String
    let topic: String
    let description: String
    let levelRaw: String
    let subjectName: String
    let storagePath: String?
    let originalFileName: String
    let folderId: UUID?
    let uploaderId: UUID?
    let uploaderName: String

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
        case topic
        case description
        case levelRaw = "level_raw"
        case subjectName = "subject_name"
        case storagePath = "storage_path"
        case originalFileName = "original_file_name"
        case folderId = "folder_id"
        case uploaderId = "uploader_id"
        case uploaderName = "uploader_name"
    }
}
