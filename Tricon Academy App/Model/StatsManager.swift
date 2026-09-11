import Foundation
import Combine

/// Lightweight learning activity: weekly stats, streak, last subject, and a daily goal.
/// Persisted in UserDefaults — no server required.
final class StatsManager: ObservableObject {
    static let shared = StatsManager()

    enum ResourceKind: String {
        case paper
        case notes
        case video

        var displayName: String {
            switch self {
            case .paper: return "Paper"
            case .notes: return "Notes"
            case .video: return "Video"
            }
        }
    }

    @Published private(set) var papersSolvedThisWeek: Int = 0
    @Published private(set) var videosWatchedThisWeek: Int = 0
    @Published private(set) var notesOpenedThisWeek: Int = 0
    @Published private(set) var dayStreak: Int = 0

    @Published private(set) var lastSubjectName: String = ""
    @Published private(set) var lastTopicTitle: String = ""
    @Published private(set) var lastLevelRaw: String = ""
    @Published private(set) var lastKindRaw: String = ""

    @Published private(set) var resourcesOpenedToday: Int = 0

    /// Daily unique resources to open. Small on purpose so it fills in as they study.
    let dailyGoal: Int = 3

    private let defaults: UserDefaults
    private var openedContentIds: Set<String> = []
    private var todayOpenedIds: Set<String> = []

    private enum Keys {
        static let papersCount = "stats.papersCount"
        static let videosCount = "stats.videosCount"
        static let notesCount = "stats.notesCount"
        static let weekStart = "stats.weekStart"
        static let dayStreak = "stats.dayStreak"
        static let lastActiveDay = "stats.lastActiveDay"
        static let lastSubject = "stats.lastSubject"
        static let lastTopic = "stats.lastTopic"
        static let lastLevel = "stats.lastLevel"
        static let lastKind = "stats.lastKind"
        static let openedIds = "stats.openedContentIds"
        static let todayCount = "stats.todayCount"
        static let todayIds = "stats.todayOpenedIds"
        static let todayDate = "stats.todayDate"
    }

    var lastKind: ResourceKind? {
        ResourceKind(rawValue: lastKindRaw)
    }

    var hasContinueLearning: Bool {
        !lastSubjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var dailyGoalFraction: Double {
        min(1, Double(resourcesOpenedToday) / Double(max(dailyGoal, 1)))
    }

    var dailyGoalComplete: Bool {
        resourcesOpenedToday >= dailyGoal
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        resetWeekIfNeeded()
        resetTodayIfNeeded()
        papersSolvedThisWeek = defaults.integer(forKey: Keys.papersCount)
        videosWatchedThisWeek = defaults.integer(forKey: Keys.videosCount)
        notesOpenedThisWeek = defaults.integer(forKey: Keys.notesCount)
        dayStreak = defaults.integer(forKey: Keys.dayStreak)
        lastSubjectName = defaults.string(forKey: Keys.lastSubject) ?? ""
        lastTopicTitle = defaults.string(forKey: Keys.lastTopic) ?? ""
        lastLevelRaw = defaults.string(forKey: Keys.lastLevel) ?? ""
        lastKindRaw = defaults.string(forKey: Keys.lastKind) ?? ""
        resourcesOpenedToday = defaults.integer(forKey: Keys.todayCount)
        openedContentIds = Set(defaults.stringArray(forKey: Keys.openedIds) ?? [])
        todayOpenedIds = Set(defaults.stringArray(forKey: Keys.todayIds) ?? [])
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

    func recordNotesOpened() {
        resetWeekIfNeeded()
        notesOpenedThisWeek += 1
        defaults.set(notesOpenedThisWeek, forKey: Keys.notesCount)
    }

    /// Call once when Home appears — advances or resets the day streak.
    func recordAppActive() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let lastActive = defaults.object(forKey: Keys.lastActiveDay) as? Date else {
            dayStreak = 1
            defaults.set(dayStreak, forKey: Keys.dayStreak)
            defaults.set(today, forKey: Keys.lastActiveDay)
            resetWeekIfNeeded()
            resetTodayIfNeeded()
            return
        }

        let lastActiveDay = calendar.startOfDay(for: lastActive)
        let daysBetween = calendar.dateComponents([.day], from: lastActiveDay, to: today).day ?? 0

        if daysBetween == 0 {
            // Already active today
        } else if daysBetween == 1 {
            dayStreak += 1
        } else {
            dayStreak = 1
        }

        defaults.set(dayStreak, forKey: Keys.dayStreak)
        defaults.set(today, forKey: Keys.lastActiveDay)

        resetWeekIfNeeded()
        resetTodayIfNeeded()
    }

    /// Remember the last subject hub the student opened (Continue Learning).
    func recordSubjectVisited(name: String, levelRaw: String) {
        let subject = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subject.isEmpty else { return }
        if lastSubjectName != subject || lastLevelRaw != levelRaw {
            lastTopicTitle = "Papers, notes & videos"
            lastKindRaw = ""
        }
        lastSubjectName = subject
        lastLevelRaw = levelRaw
        persistContinueLearning()
    }

    /// Remember a specific paper, note, or video and count it toward today’s goal.
    func recordResourceOpened(
        id: String,
        subject: String,
        title: String,
        kind: ResourceKind,
        levelRaw: String
    ) {
        resetTodayIfNeeded()
        resetWeekIfNeeded()

        let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSubject.isEmpty {
            lastSubjectName = trimmedSubject
        }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            lastTopicTitle = trimmedTitle
        }
        lastKindRaw = kind.rawValue
        if !levelRaw.isEmpty {
            lastLevelRaw = levelRaw
        }
        persistContinueLearning()

        let key = "\(trimmedSubject)|\(kind.rawValue)|\(id.isEmpty ? trimmedTitle : id)"
        if openedContentIds.insert(key).inserted {
            defaults.set(Array(openedContentIds), forKey: Keys.openedIds)
        }
        if todayOpenedIds.insert(key).inserted {
            resourcesOpenedToday += 1
            defaults.set(resourcesOpenedToday, forKey: Keys.todayCount)
            defaults.set(Array(todayOpenedIds), forKey: Keys.todayIds)
        }
    }

    func openedCount(forSubject name: String) -> Int {
        let prefix = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() + "|"
        return openedContentIds.filter { $0.lowercased().hasPrefix(prefix) }.count
    }

    func progress(forSubject name: String, totalResources: Int) -> Double {
        guard totalResources > 0 else { return 0 }
        let opened = min(openedCount(forSubject: name), totalResources)
        return min(1, Double(opened) / Double(totalResources))
    }

    // MARK: - Resets

    private func persistContinueLearning() {
        defaults.set(lastSubjectName, forKey: Keys.lastSubject)
        defaults.set(lastTopicTitle, forKey: Keys.lastTopic)
        defaults.set(lastLevelRaw, forKey: Keys.lastLevel)
        defaults.set(lastKindRaw, forKey: Keys.lastKind)
    }

    private func resetWeekIfNeeded(force: Bool = false) {
        let calendar = Calendar.current
        let now = Date()
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let storedWeekStart = defaults.object(forKey: Keys.weekStart) as? Date

        if force || storedWeekStart == nil || storedWeekStart != currentWeekStart {
            defaults.set(currentWeekStart, forKey: Keys.weekStart)
            defaults.set(0, forKey: Keys.papersCount)
            defaults.set(0, forKey: Keys.videosCount)
            defaults.set(0, forKey: Keys.notesCount)
            papersSolvedThisWeek = 0
            videosWatchedThisWeek = 0
            notesOpenedThisWeek = 0
        }
    }

    private func resetTodayIfNeeded(force: Bool = false) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let stored = defaults.object(forKey: Keys.todayDate) as? Date
        let storedDay = stored.map { calendar.startOfDay(for: $0) }
        if force || storedDay == nil || storedDay != today {
            defaults.set(today, forKey: Keys.todayDate)
            defaults.set(0, forKey: Keys.todayCount)
            defaults.set([String](), forKey: Keys.todayIds)
            resourcesOpenedToday = 0
            todayOpenedIds = []
        }
    }
}
