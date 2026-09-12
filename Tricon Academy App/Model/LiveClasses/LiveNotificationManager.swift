import Foundation
import UserNotifications

final class LiveNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = LiveNotificationManager()
    private let center = UNUserNotificationCenter.current()
    var openLesson: ((UUID) -> Void)?
    func install() { center.delegate = self }
    func requestPermission() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }
    func reconcile(lessons: [LiveLesson], reminders: Set<UUID>, userID: UUID) async throws {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix("live.") }.map(\.identifier))
        // Stay below iOS's 64 pending-notification limit, nearest lessons first.
        var count = 0
        for lesson in lessons.filter({ $0.status == .scheduled && reminders.contains($0.id) }).sorted(by: { $0.scheduledAt < $1.scheduledAt }) {
            for minutes in [60, 15] {
                let fire = lesson.scheduledAt.addingTimeInterval(Double(-minutes * 60))
                guard fire > Date(), count < 50 else { continue }
                let content = UNMutableNotificationContent()
                content.title = "Class starts in \(minutes) minutes"
                content.body = "\(lesson.subject): \(lesson.topic)"
                content.sound = .default
                content.userInfo = ["lesson_id": lesson.id.uuidString, "user_id": userID.uuidString]
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, fire.timeIntervalSinceNow), repeats: false)
                try await center.add(UNNotificationRequest(identifier: "live.\(userID).\(lesson.id).\(minutes)", content: content, trigger: trigger))
                count += 1
            }
        }
    }
    func clear() {
        center.getPendingNotificationRequests { requests in
            self.center.removePendingNotificationRequests(withIdentifiers: requests.filter { $0.identifier.hasPrefix("live.") }.map(\.identifier))
        }
        center.getDeliveredNotifications { notifications in
            self.center.removeDeliveredNotifications(withIdentifiers: notifications.filter { $0.request.identifier.hasPrefix("live.") }.map { $0.request.identifier })
        }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        if let raw = info["lesson_id"] as? String, let id = UUID(uuidString: raw),
           let owner = info["user_id"] as? String, owner == SupabaseClient.shared.userId?.uuidString {
            DispatchQueue.main.async { self.openLesson?(id) }
        }
        completionHandler()
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let owner = notification.request.content.userInfo["user_id"] as? String
        completionHandler(owner == SupabaseClient.shared.userId?.uuidString ? [.banner, .sound] : [])
    }
}
