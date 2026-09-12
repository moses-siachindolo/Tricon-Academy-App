import Foundation

/// All calls use the existing client, including its refresh/retry behavior.
struct LiveClassesService {
    let client = SupabaseClient.shared
    func lessons() async throws -> [LiveLesson] {
        try await client.select(table: "live_lessons", query: "select=*&order=scheduled_at.asc")
    }
    func tutors() async throws -> [RemoteProfile] {
        try await client.select(table: "profiles", query: "select=*&role=in.(tutor,admin)&is_blocked=eq.false&is_removed=eq.false&order=full_name")
    }
    func recordings() async throws -> [LiveRecording] {
        try await client.select(table: "live_lesson_recordings", query: "select=*&status=eq.ready&order=created_at.desc")
    }
    func notifications() async throws -> [AcademyNotification] {
        try await client.select(table: "academy_notifications", query: "select=*&order=created_at.desc&limit=100")
    }
    func reminders() async throws -> [LiveReminder] { try await client.select(table: "live_lesson_reminders") }
    func attendance(_ id: UUID) async throws -> [LiveAttendance] {
        try await client.select(table: "live_lesson_participants", query: "select=*,profile:profiles!live_lesson_participants_user_id_fkey(full_name)&lesson_id=eq.\(id)&order=joined_at.desc")
    }
    func save(_ lesson: LiveLesson, editing: Bool) async throws {
        if editing {
            struct Edit: Encodable {
                let tutor_id: UUID
                let subject: String
                let topic: String
                let grade: String
                let scheduled_at: Date
                let duration_minutes: Int
                let recording_enabled: Bool
                let recording_folder: String
            }
            let values = Edit(tutor_id: lesson.tutorID, subject: lesson.subject, topic: lesson.topic, grade: lesson.grade, scheduled_at: lesson.scheduledAt, duration_minutes: lesson.durationMinutes, recording_enabled: lesson.recordingEnabled, recording_folder: lesson.recordingFolder)
            let data = try await client.perform(path: "/rest/v1/live_lessons?id=eq.\(lesson.id)&status=eq.scheduled", method: "PATCH", body: values, rawBody: nil, useUserToken: true, extraHeaders: ["Prefer": "return=representation"])
            guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]], !rows.isEmpty else { throw SupabaseError.message("This lesson changed or you no longer have permission. Refresh and try again.") }
        }
        else { let _: LiveLesson = try await client.insert(table: "live_lessons", row: lesson) }
    }
    func rpc(_ name: String, lessonID: UUID) async throws {
        let _ = try await client.perform(path: "/rest/v1/rpc/\(name)", method: "POST", body: ["p_lesson_id": lessonID.uuidString], rawBody: nil, useUserToken: true, extraHeaders: [:])
    }
    func markRead(_ id: UUID) async throws {
        struct Read: Encodable { let read_at: Date }
        try await client.update(table: "academy_notifications", query: "id=eq.\(id)", values: Read(read_at: Date()))
    }
    func reminder(_ id: UUID, enabled: Bool) async throws {
        guard let userID = client.userId else { throw SupabaseError.noSession }
        if enabled {
            let _ = try await client.perform(path: "/rest/v1/live_lesson_reminders", method: "POST", body: ["lesson_id": id.uuidString, "user_id": userID.uuidString], rawBody: nil, useUserToken: true, extraHeaders: ["Prefer": "resolution=ignore-duplicates,return=minimal"])
        } else { try await client.delete(table: "live_lesson_reminders", query: "lesson_id=eq.\(id)&user_id=eq.\(userID)") }
    }
    func playback(_ recording: LiveRecording) async throws -> URL {
        struct Signed: Decodable { let signedURL: String }
        let path = recording.storagePath.split(separator: "/").map { String($0).addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "" }.joined(separator: "/")
        let data = try await client.perform(path: "/storage/v1/object/sign/live-recordings/\(path)", method: "POST", body: ["expiresIn": 3600], rawBody: nil, useUserToken: true, extraHeaders: [:])
        let signed = try JSONDecoder().decode(Signed.self, from: data)
        guard let root = URL(string: SupabaseConfig.projectURL),
              let url = URL(string: "/storage/v1" + signed.signedURL, relativeTo: root)?.absoluteURL,
              url.scheme == "https", url.host == root.host else { throw SupabaseError.invalidURL }
        return url
    }
}
