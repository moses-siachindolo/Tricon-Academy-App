"""Run persistence regressions on macOS without the iOS SDK.

Uses the production managers and Foundation-only portions of curriculum models.
UIKit presentation properties are excluded from this standalone harness.
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
curriculum = (root / 'Model/Curriculum/CurriculumModels.swift').read_text()
level = curriculum[curriculum.index('enum Level:'):curriculum.index('    /// Distinct accent')] + '}\n'
content = curriculum[curriculum.index('struct PastPaper:'):curriculum.index('// MARK: - App theme')]
source = 'import Foundation\nimport Combine\n' + level + content
for name in ['SavedItemsManager', 'StatsManager']:
    source += (root / f'Model/{name}.swift').read_text() + '\n'
source += r'''
let suite = "tricon.regression.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let saved = SavedItemsManager(defaults: defaults)
let studentID = UUID()
let tutorID = UUID()
saved.setUser(studentID)
let paper = PastPaper(id: "paper", title: "Exam", year: 2021, fileName: "exam.pdf", level: .form2, subjectName: "Physics")
saved.togglePaper(paper)
assert(saved.items.first?.year == 2021)
let notes = StudyMaterial(id: "notes", title: "Forces", topic: "Dynamics", fileName: "notes.pdf", level: .form2, subjectName: "Physics")
saved.toggleMaterial(notes)
let video = VideoLesson(id: "video", title: "Motion", topic: "Kinematics", fileName: "motion", fileExtension: "mp4", level: .form2, subjectName: "Physics", durationLabel: "24 min")
saved.toggleVideo(video)
let restored = SavedItemsManager(defaults: defaults)
assert(restored.items.isEmpty, "Bookmarks stay hidden until an account is selected")
restored.setUser(studentID)
assert(restored.items.count == 3)
assert(restored.items.first?.durationLabel == "24 min")
assert(restored.items.first?.topic == "Kinematics")
assert(restored.items.last?.year == 2021)
saved.toggleVideo(video)
assert(!saved.isSaved(id: "video"))

// Existing bookmarks must decode when the new optional metadata is absent.
let encoded = try JSONEncoder().encode(restored.items)
var legacy = try JSONSerialization.jsonObject(with: encoded) as! [[String: Any]]
for i in legacy.indices {
    legacy[i].removeValue(forKey: "year")
    legacy[i].removeValue(forKey: "topic")
    legacy[i].removeValue(forKey: "durationLabel")
}
let legacyData = try JSONSerialization.data(withJSONObject: legacy)
let decoded = try JSONDecoder().decode([SavedItem].self, from: legacyData)
assert(decoded.count == 3 && decoded.allSatisfy { $0.year == nil && $0.topic == nil && $0.durationLabel == nil })

// A shared installation must keep student and tutor bookmarks independent.
defaults.set(legacyData, forKey: "saved.items.v1")
saved.setUser(tutorID)
assert(saved.items.isEmpty, "A new account must not inherit current or legacy shared bookmarks")
saved.togglePaper(paper)
saved.toggleVideo(video)
saved.remove(id: paper.id)
assert(saved.items.map(\.id) == [video.id])
saved.setUser(studentID)
assert(Set(saved.items.map(\.id)) == Set([paper.id, notes.id]), "Tutor changes must not affect the student")
saved.setUser(tutorID)
assert(saved.items.map(\.id) == [video.id])
saved.clearAll()
saved.setUser(studentID)
assert(saved.items.count == 2, "Clear all must only clear the active account")
saved.setUser(nil)
assert(saved.items.isEmpty && !saved.isSaved(id: paper.id), "Logout clears visible bookmarks")
saved.togglePaper(paper)
saved.toggleMaterial(notes)
saved.toggleVideo(video)
saved.remove(id: paper.id)
saved.clearAll()
assert(saved.items.isEmpty, "Signed-out actions must not save anything")
let relaunched = SavedItemsManager(defaults: defaults)
relaunched.setUser(studentID)
assert(Set(relaunched.items.map(\.id)) == Set([paper.id, notes.id]), "Account bookmarks survive relaunch and signed-out actions")
relaunched.setUser(tutorID)
assert(relaunched.items.isEmpty, "Account-specific clearing persists across relaunch")
assert(defaults.data(forKey: "saved.items.v1") == legacyData, "Unowned legacy data is preserved without exposing it")

let stats = StatsManager(defaults: defaults)
stats.recordPaperOpened()
stats.recordResourceOpened(id: "p", subject: "Physics", title: "Motion", kind: .paper, levelRaw: "Form 1")
stats.recordAppActive()
assert(stats.papersSolvedThisWeek == 1, "First home visit must not erase study activity")
assert(stats.resourcesOpenedToday == 1)
stats.recordResourceOpened(id: "p", subject: "Physics", title: "Motion", kind: .paper, levelRaw: "Form 1")
assert(stats.resourcesOpenedToday == 1, "Daily goal counts unique resources")
stats.recordResourceOpened(id: "n", subject: "Applied Physics", title: "Physics", kind: .notes, levelRaw: "Form 1")
assert(stats.openedCount(forSubject: "Physics") == 1, "Subject progress must match the full subject")
stats.recordSubjectVisited(name: "Applied Physics", levelRaw: "Form 2")
assert(stats.lastKindRaw.isEmpty && stats.lastTopicTitle == "Papers, notes & videos")
assert(stats.lastLevelRaw == "Form 2")
let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
defaults.set(previousDay, forKey: "stats.todayDate")
stats.recordAppActive()
assert(stats.resourcesOpenedToday == 0, "Foreground refresh rolls over daily progress")
print("PASS: bookmark account isolation, logout, relaunch, legacy isolation, metadata, toggle persistence, first activity, daily uniqueness, subject matching, form switching, daily rollover")
'''
with tempfile.TemporaryDirectory(prefix='tricon-regressions-') as directory:
    temp = Path(directory)
    swift = temp / 'main.swift'
    swift.write_text(source)
    binary = temp / 'regressions'
    subprocess.run(['swiftc', '-module-cache-path', str(Path(tempfile.gettempdir()) / 'tricon-swift-module-cache'), str(swift), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
