import Foundation

enum LiveLessonStatus: String, Codable, CaseIterable { case scheduled, live, completed, cancelled }

struct LiveLesson: Codable, Identifiable, Equatable {
    var id: UUID
    var tutorID: UUID
    var subject: String
    var topic: String
    var grade: String
    var scheduledAt: Date
    var durationMinutes: Int
    var status: LiveLessonStatus
    var recordingEnabled: Bool
    var recordingFolder: String
    var recordingActive: Bool = false
    enum CodingKeys: String, CodingKey {
        case id, subject, topic, grade, status
        case tutorID = "tutor_id", scheduledAt = "scheduled_at", durationMinutes = "duration_minutes"
        case recordingEnabled = "recording_enabled", recordingFolder = "recording_folder", recordingActive = "recording_active"
    }
    var invitationURL: URL { URL(string: "triconacademy://live/\(id.uuidString.lowercased())")! }
    static func lessonID(from url: URL) -> UUID? {
        guard url.scheme?.lowercased() == "triconacademy", url.host == "live",
              url.user == nil, url.password == nil, url.port == nil,
              url.query == nil, url.fragment == nil, url.pathComponents.count == 2 else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
    func canManage(_ user: User?) -> Bool {
        guard let user else { return false }
        return user.isAdmin || (user.id == tutorID && user.canManageSubject(subject))
    }
}

struct LiveAttendance: Decodable, Identifiable {
    let id: UUID
    let userID: UUID
    let joinedAt: Date
    let leftAt: Date?
    let profile: ProfileName?
    struct ProfileName: Decodable { let full_name: String }
    var displayName: String { profile?.full_name ?? userID.uuidString }
    enum CodingKeys: String, CodingKey { case id, profile; case userID = "user_id", joinedAt = "joined_at", leftAt = "left_at" }
}
struct LiveRecording: Decodable, Identifiable {
    let id: UUID
    let lessonID: UUID
    let title: String
    let folder: String
    let storagePath: String
    enum CodingKeys: String, CodingKey { case id, title, folder; case lessonID = "lesson_id", storagePath = "storage_path" }
}
struct AcademyNotification: Decodable, Identifiable {
    let id: UUID
    let lessonID: UUID
    let title: String
    let body: String
    let createdAt: Date
    let readAt: Date?
    enum CodingKeys: String, CodingKey { case id, title, body; case lessonID = "lesson_id", createdAt = "created_at", readAt = "read_at" }
}
struct LiveReminder: Decodable {
    let lessonID: UUID
    enum CodingKeys: String, CodingKey { case lessonID = "lesson_id" }
}
