import Foundation
import Combine

/// Tracks lightweight activity stats (papers opened, videos watched, day streak)
/// shown in the Home screen's "This week" section. Persisted with UserDefaults —
/// no server or CoreData needed for this.
final class StatsManager: ObservableObject {
    static let shared = StatsManager()

    @Published private(set) var papersSolvedThisWeek: Int = 0
    @Published private(set) var videosWatchedThisWeek: Int = 0
    @Published private(set) var dayStreak: Int = 0

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let papersCount = "stats.papersCount"
        static let videosCount = "stats.videosCount"
        static let weekStart = "stats.weekStart"
        static let dayStreak = "stats.dayStreak"
        static let lastActiveDay = "stats.lastActiveDay"
    }

    private init() {
        resetWeekIfNeeded()
        papersSolvedThisWeek = defaults.integer(forKey: Keys.papersCount)
        videosWatchedThisWeek = defaults.integer(forKey: Keys.videosCount)
        dayStreak = defaults.integer(forKey: Keys.dayStreak)
    }

    // MARK: - Public actions

    /// Call when the user opens an actual past paper (not materials).
    func recordPaperOpened() {
        resetWeekIfNeeded()
        papersSolvedThisWeek += 1
        defaults.set(papersSolvedThisWeek, forKey: Keys.papersCount)
    }

    /// Call when the user opens a video lesson.
    func recordVideoWatched() {
        resetWeekIfNeeded()
        videosWatchedThisWeek += 1
        defaults.set(videosWatchedThisWeek, forKey: Keys.videosCount)
    }

    /// Call once when Home appears — advances or resets the day streak.
    func recordAppActive() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let lastActive = defaults.object(forKey: Keys.lastActiveDay) as? Date else {
            // First ever launch
            dayStreak = 1
            defaults.set(dayStreak, forKey: Keys.dayStreak)
            defaults.set(today, forKey: Keys.lastActiveDay)
            resetWeekIfNeeded(force: true)
            return
        }

        let lastActiveDay = calendar.startOfDay(for: lastActive)
        let daysBetween = calendar.dateComponents([.day], from: lastActiveDay, to: today).day ?? 0

        if daysBetween == 0 {
            // Already active today — nothing to change
        } else if daysBetween == 1 {
            dayStreak += 1
        } else {
            dayStreak = 1
        }

        defaults.set(dayStreak, forKey: Keys.dayStreak)
        defaults.set(today, forKey: Keys.lastActiveDay)

        resetWeekIfNeeded()
    }

    // MARK: - Weekly reset

    private func resetWeekIfNeeded(force: Bool = false) {
        let calendar = Calendar.current
        let now = Date()
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let storedWeekStart = defaults.object(forKey: Keys.weekStart) as? Date

        if force || storedWeekStart == nil || storedWeekStart != currentWeekStart {
            defaults.set(currentWeekStart, forKey: Keys.weekStart)
            defaults.set(0, forKey: Keys.papersCount)
            defaults.set(0, forKey: Keys.videosCount)
            papersSolvedThisWeek = 0
            videosWatchedThisWeek = 0
        }
    }
}
