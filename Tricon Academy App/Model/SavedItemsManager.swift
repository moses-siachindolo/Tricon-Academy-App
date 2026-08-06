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

/// Local bookmarks for papers, notes, and videos.
final class SavedItemsManager: ObservableObject {
    static let shared = SavedItemsManager()

    @Published private(set) var items: [SavedItem] = []

    private let defaults = UserDefaults.standard
    private let storageKey = "saved.items.v1"

    private init() {
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
            dateSaved: Date()
        )
        toggle(item)
    }

    func remove(id: String) {
        items.removeAll { $0.id == id }
        persist()
    }

    func clearAll() {
        items.removeAll()
        persist()
    }

    private func toggle(_ item: SavedItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
        } else {
            items.insert(item, at: 0)
        }
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SavedItem].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
