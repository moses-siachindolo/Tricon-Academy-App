import Foundation
import Combine

enum SavedItemKind: String, Codable, Hashable {
    case paper
    case material
    case video
}

struct SavedItem: Identifiable, Codable, Hashable {
    let id: String
    let kind: SavedItemKind
    let title: String
    let subtitle: String
    let levelRaw: String
    let subjectName: String
    let fileName: String
    let fileExtension: String
    let isPastPaper: Bool
    var year: Int? = nil
    var topic: String? = nil
    var durationLabel: String? = nil
    let dateSaved: Date

    var level: Level {
        Level(rawValue: levelRaw) ?? .form1
    }

    var icon: String {
        switch kind {
        case .paper: return "doc.text.fill"
        case .material: return "note.text"
        case .video: return "play.rectangle.fill"
        }
    }
}

/// Local, account-specific bookmarks for papers, notes, and videos.
final class SavedItemsManager: ObservableObject {
    static let shared = SavedItemsManager()

    @Published private(set) var items: [SavedItem] = []

    private let defaults: UserDefaults
    private var userID: UUID?
    private var storageKey: String? {
        userID.map { "saved.items.v2.\($0.uuidString.lowercased())" }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Called synchronously by authentication before showing another account's UI.
    func setUser(_ userID: UUID?) {
        guard self.userID != userID else { return }
        self.userID = userID
        load()
    }

    func isSaved(id: String) -> Bool {
        items.contains { $0.id == id }
    }

    func togglePaper(_ paper: PastPaper) {
        let item = SavedItem(
            id: paper.id,
            kind: .paper,
            title: paper.title,
            subtitle: "\(paper.year) · \(paper.level.rawValue)",
            levelRaw: paper.level.rawValue,
            subjectName: paper.subjectName,
            fileName: paper.fileName,
            fileExtension: "pdf",
            isPastPaper: true,
            year: paper.year,
            dateSaved: Date()
        )
        toggle(item)
    }

    func toggleMaterial(_ material: StudyMaterial) {
        let item = SavedItem(
            id: material.id,
            kind: .material,
            title: material.title,
            subtitle: "\(material.topic) · \(material.level.rawValue)",
            levelRaw: material.level.rawValue,
            subjectName: material.subjectName,
            fileName: material.fileName,
            fileExtension: "pdf",
            isPastPaper: false,
            topic: material.topic,
            dateSaved: Date()
        )
        toggle(item)
    }

    func toggleVideo(_ video: VideoLesson) {
        let item = SavedItem(
            id: video.id,
            kind: .video,
            title: video.title,
            subtitle: "\(video.topic) · \(video.level.rawValue)",
            levelRaw: video.level.rawValue,
            subjectName: video.subjectName,
            fileName: video.fileName,
            fileExtension: video.fileExtension,
            isPastPaper: false,
            topic: video.topic,
            durationLabel: video.durationLabel,
            dateSaved: Date()
        )
        toggle(item)
    }

    func remove(id: String) {
        guard userID != nil else { return }
        items.removeAll { $0.id == id }
        persist()
    }

    func clearAll() {
        guard userID != nil else { return }
        items.removeAll()
        persist()
    }

    private func toggle(_ item: SavedItem) {
        guard userID != nil else { return }
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
        } else {
            items.insert(item, at: 0)
        }
        persist()
    }

    private func load() {
        // The old shared key has no owner. Preserve it on disk, but never import
        // it into an account, where it could expose another user's bookmarks.
        guard let storageKey,
              let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SavedItem].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }

    private func persist() {
        guard let storageKey,
              let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
