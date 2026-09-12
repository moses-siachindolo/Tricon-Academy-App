import Foundation
import Combine

@MainActor final class LiveClassesStore: ObservableObject {
    static let shared = LiveClassesStore()
    @Published var lessons: [LiveLesson] = []
    @Published var recordings: [LiveRecording] = []
    @Published var notifications: [AcademyNotification] = []
    @Published var tutors: [RemoteProfile] = []
    @Published var reminders = Set<UUID>()
    @Published var error: String?
    @Published var busy = false
    @Published var pendingLessonID: UUID?
    let service = LiveClassesService()
    private var accountID: UUID?
    var unreadCount: Int { notifications.filter { $0.readAt == nil }.count }
    func setAccount(_ id: UUID?) {
        guard id != accountID else { return }
        accountID = id
        if id == nil { pendingLessonID = nil }
        lessons = []; recordings = []; notifications = []; tutors = []; reminders = []; error = nil
        LiveNotificationManager.shared.clear()
    }
    func refresh() async {
        guard let id = accountID else { return }
        do {
            let rows = try await service.lessons()
            let videos = try await service.recordings()
            let updates = try await service.notifications()
            let saved = try await service.reminders()
            guard id == accountID else { return }
            lessons = rows; recordings = videos; notifications = updates
            reminders = Set(saved.map(\.lessonID)); error = nil
            try await LiveNotificationManager.shared.reconcile(lessons: rows, reminders: reminders, userID: id)
        } catch { if id == accountID { self.error = error.localizedDescription } }
    }
    @discardableResult func perform(_ action: () async throws -> Void) async -> Bool {
        guard !busy else { return false }
        let owner = accountID
        busy = true; error = nil
        defer { busy = false }
        do {
            try await action()
            guard owner == accountID else { return false }
            await refresh(); return true
        } catch { if owner == accountID { self.error = error.localizedDescription }; return false }
    }
    func loadTutors() async {
        do { tutors = try await service.tutors() } catch { self.error = error.localizedDescription }
    }
    func setReminder(_ lesson: LiveLesson, enabled: Bool) async {
        await perform {
            try await service.reminder(lesson.id, enabled: enabled)
            if enabled {
                let granted = try await LiveNotificationManager.shared.requestPermission()
                if !granted { throw SupabaseError.message("Reminder saved in Updates. Enable notifications in iOS Settings for device alerts.") }
            }
        }
    }
}
