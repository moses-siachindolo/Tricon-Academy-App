import Foundation
import Combine

// MARK: - Sections & folders

/// Content tabs under a subject: papers, notes, or videos.
enum ContentSection: String, Codable, CaseIterable, Identifiable {
    case papers
    case notes
    case videos

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .papers: return "Papers"
        case .notes: return "Notes"
        case .videos: return "Videos"
        }
    }

    var folderPlaceholder: String {
        switch self {
        case .papers: return "e.g. 2018, 2019, Mid-year"
        case .notes: return "e.g. Kinematics, Organic Chemistry"
        case .videos: return "e.g. Mechanics, Exam prep"
        }
    }

    var icon: String {
        switch self {
        case .papers: return "folder.fill"
        case .notes: return "folder.fill"
        case .videos: return "folder.fill"
        }
    }
}

/// Staff-created folder used to group papers, notes, or videos.
/// Supports nested “mini folders” via `parentFolderId`.
struct ContentFolder: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let section: ContentSection
    let levelRaw: String
    let subjectName: String
    let createdAt: Date
    /// `nil` = top-level folder in a section; otherwise nested under another folder.
    let parentFolderId: UUID?

    var level: Level {
        Level(rawValue: levelRaw) ?? .form1
    }

    init(
        id: UUID,
        name: String,
        section: ContentSection,
        levelRaw: String,
        subjectName: String,
        createdAt: Date,
        parentFolderId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.section = section
        self.levelRaw = levelRaw
        self.subjectName = subjectName
        self.createdAt = createdAt
        self.parentFolderId = parentFolderId
    }

    enum CodingKeys: String, CodingKey {
        case id, name, section, levelRaw, subjectName, createdAt, parentFolderId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        section = try c.decode(ContentSection.self, forKey: .section)
        levelRaw = try c.decode(String.self, forKey: .levelRaw)
        subjectName = try c.decode(String.self, forKey: .subjectName)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        parentFolderId = try c.decodeIfPresent(UUID.self, forKey: .parentFolderId)
    }
}

enum LibraryContentKind: String, Codable {
    case document // legacy — treated as paper when section is missing
    case paper
    case note
    case video

    var section: ContentSection {
        switch self {
        case .document, .paper: return .papers
        case .note: return .notes
        case .video: return .videos
        }
    }
}

/// User-uploaded content that appears alongside curriculum data.
struct LibraryItem: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: LibraryContentKind
    let title: String
    let topic: String
    let description: String
    let levelRaw: String
    let subjectName: String
    /// Absolute path if a local file was copied, otherwise empty.
    let localFilePath: String
    let originalFileName: String
    let createdAt: Date
    let uploaderName: String
    /// Optional folder this item belongs to (admin-organized).
    let folderId: UUID?

    var level: Level {
        Level(rawValue: levelRaw) ?? .form1
    }

    var section: ContentSection {
        kind.section
    }

    var asPastPaper: PastPaper? {
        guard kind == .document || kind == .paper else { return nil }
        return PastPaper(
            id: "library-paper-\(id.uuidString)",
            title: title,
            year: yearFromTopicOrDate,
            fileName: localFilePath.isEmpty ? "sample_paper" : localFilePath,
            level: level,
            subjectName: subjectName
        )
    }

    func asStudyMaterial() -> StudyMaterial? {
        guard kind == .note else { return nil }
        return StudyMaterial(
            id: "library-material-\(id.uuidString)",
            title: title,
            topic: topic.isEmpty ? "Uploaded" : topic,
            fileName: localFilePath.isEmpty ? "sample_notes" : localFilePath,
            level: level,
            subjectName: subjectName
        )
    }

    var asVideo: VideoLesson? {
        guard kind == .video else { return nil }
        let ext = (originalFileName as NSString).pathExtension
        return VideoLesson(
            id: "library-video-\(id.uuidString)",
            title: title,
            topic: topic.isEmpty ? "Uploaded lesson" : topic,
            fileName: localFilePath.isEmpty ? "sample_video" : localFilePath,
            fileExtension: ext.isEmpty ? "mp4" : ext,
            level: level,
            subjectName: subjectName,
            durationLabel: "Uploaded"
        )
    }

    private var yearFromTopicOrDate: Int {
        if let y = Int(topic.trimmingCharacters(in: .whitespaces)), (1990...2100).contains(y) {
            return y
        }
        return Calendar.current.component(.year, from: createdAt)
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, title, topic, description, levelRaw, subjectName
        case localFilePath, originalFileName, createdAt, uploaderName, folderId
    }

    init(
        id: UUID,
        kind: LibraryContentKind,
        title: String,
        topic: String,
        description: String,
        levelRaw: String,
        subjectName: String,
        localFilePath: String,
        originalFileName: String,
        createdAt: Date,
        uploaderName: String,
        folderId: UUID?
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.topic = topic
        self.description = description
        self.levelRaw = levelRaw
        self.subjectName = subjectName
        self.localFilePath = localFilePath
        self.originalFileName = originalFileName
        self.createdAt = createdAt
        self.uploaderName = uploaderName
        self.folderId = folderId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        let rawKind = try c.decode(String.self, forKey: .kind)
        switch rawKind {
        case "video": kind = .video
        case "note": kind = .note
        case "paper": kind = .paper
        default: kind = .paper // legacy "document" → paper
        }
        title = try c.decode(String.self, forKey: .title)
        topic = try c.decode(String.self, forKey: .topic)
        description = try c.decode(String.self, forKey: .description)
        levelRaw = try c.decode(String.self, forKey: .levelRaw)
        subjectName = try c.decode(String.self, forKey: .subjectName)
        localFilePath = try c.decode(String.self, forKey: .localFilePath)
        originalFileName = try c.decode(String.self, forKey: .originalFileName)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        uploaderName = try c.decode(String.self, forKey: .uploaderName)
        folderId = try c.decodeIfPresent(UUID.self, forKey: .folderId)
    }
}

/// Content library for tutor/admin uploads (local cache + optional Supabase cloud).
@MainActor
final class ContentLibrary: ObservableObject {
    static let shared = ContentLibrary()

    @Published private(set) var items: [LibraryItem] = []
    @Published private(set) var folders: [ContentFolder] = []
    @Published private(set) var lastSyncError: String?
    @Published private(set) var isSyncing = false

    private let defaults = UserDefaults.standard
    private let itemsKey = "content.library.v2"
    private let legacyItemsKey = "content.library.v1"
    private let foldersKey = "content.folders.v2"
    private let folderName = "UploadedContent"
    private let client = SupabaseClient.shared

    private var usesCloud: Bool { client.isConfigured && client.currentSession != nil }

    private init() {
        load()
    }

    // MARK: - Cloud sync

    /// Pull folders + items from Supabase. Network work is off the main actor with a timeout
    /// so a dead Supabase project cannot freeze the UI.
    func refreshFromCloud() async {
        guard client.isConfigured, client.currentSession != nil else { return }
        guard !isSyncing else { return }
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        do {
            let (remoteFolders, remoteItems): ([RemoteFolder], [RemoteLibraryItem]) = try await withThrowingTaskGroup(
                of: ([RemoteFolder], [RemoteLibraryItem]).self
            ) { group in
                group.addTask {
                    // Nonisolated network via shared client (URLSession).
                    let folders: [RemoteFolder] = try await SupabaseClient.shared.select(
                        table: "content_folders",
                        query: "select=*&order=name.asc"
                    )
                    let items: [RemoteLibraryItem] = try await SupabaseClient.shared.select(
                        table: "library_items",
                        query: "select=*&order=created_at.desc"
                    )
                    return (folders, items)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 6_000_000_000) // 6s hard timeout
                    throw SupabaseError.message("Content sync timed out — showing cached data.")
                }
                guard let first = try await group.next() else {
                    throw SupabaseError.message("Content sync timed out — showing cached data.")
                }
                group.cancelAll()
                return first
            }
            folders = remoteFolders.map(\.asContentFolder)
            items = remoteItems.map(\.asLibraryItem)
            persistFolders()
            persistItems()
        } catch {
            // Keep local cache; never clear on server failure.
            lastSyncError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Queries

    /// Top-level folders when `parentId` is nil; otherwise direct children of that folder.
    func folders(level: Level, subject: String, section: ContentSection, parentId: UUID? = nil) -> [ContentFolder] {
        folders
            .filter {
                $0.level == level
                    && $0.subjectName == subject
                    && $0.section == section
                    && $0.parentFolderId == parentId
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func childFolders(of parentId: UUID) -> [ContentFolder] {
        folders
            .filter { $0.parentFolderId == parentId }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// All folders in a section (any depth) for pickers — shows path-style names.
    func allFoldersFlat(level: Level, subject: String, section: ContentSection) -> [(folder: ContentFolder, path: String)] {
        func path(for folder: ContentFolder) -> String {
            var parts = [folder.name]
            var current = folder
            while let pid = current.parentFolderId,
                  let parent = folders.first(where: { $0.id == pid }) {
                parts.insert(parent.name, at: 0)
                current = parent
            }
            return parts.joined(separator: " / ")
        }
        return folders
            .filter { $0.level == level && $0.subjectName == subject && $0.section == section }
            .map { ($0, path(for: $0)) }
            .sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
    }

    func itemCount(in folderId: UUID) -> Int {
        let direct = items.filter { $0.folderId == folderId }.count
        let nested = childFolders(of: folderId).count
        return direct + nested
    }

    func papers(level: Level, subject: String, folderId: UUID? = nil, unfiledOnly: Bool = false) -> [PastPaper] {
        filteredItems(level: level, subject: subject, kinds: [.paper, .document], folderId: folderId, unfiledOnly: unfiledOnly)
            .compactMap(\.asPastPaper)
    }

    func materials(level: Level, subject: String, folderId: UUID? = nil, unfiledOnly: Bool = false) -> [StudyMaterial] {
        filteredItems(level: level, subject: subject, kinds: [.note], folderId: folderId, unfiledOnly: unfiledOnly)
            .compactMap { $0.asStudyMaterial() }
    }

    func videos(level: Level, subject: String, folderId: UUID? = nil, unfiledOnly: Bool = false) -> [VideoLesson] {
        filteredItems(level: level, subject: subject, kinds: [.video], folderId: folderId, unfiledOnly: unfiledOnly)
            .compactMap(\.asVideo)
    }

    private func filteredItems(
        level: Level,
        subject: String,
        kinds: [LibraryContentKind],
        folderId: UUID?,
        unfiledOnly: Bool
    ) -> [LibraryItem] {
        items.filter { item in
            guard kinds.contains(item.kind) || (kinds.contains(.paper) && item.kind == .document) else { return false }
            guard item.level == level && item.subjectName == subject else { return false }
            if let folderId {
                return item.folderId == folderId
            }
            if unfiledOnly {
                return item.folderId == nil
            }
            return true
        }
    }

    // MARK: - Staff subject scope

    /// Tutors may only organise content for their specialist subjects; admins: all.
    private func staffCanManage(subjectName: String) -> Bool {
        guard let user = AuthManager.shared.currentUser, user.canManageContent else {
            return false
        }
        return user.canManageSubject(subjectName)
    }

    // MARK: - Folders

    @discardableResult
    func createFolder(
        name: String,
        section: ContentSection,
        level: Level,
        subjectName: String,
        parentFolderId: UUID? = nil
    ) -> ContentFolder? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        // Enforce specialist scope even if UI is bypassed.
        guard staffCanManage(subjectName: subjectName) else {
            lastSyncError = "You can only create folders for your specialist subjects."
            return nil
        }

        // Parent must match same section/level/subject when provided.
        if let parentFolderId {
            guard let parent = folders.first(where: { $0.id == parentFolderId }),
                  parent.section == section,
                  parent.level == level,
                  parent.subjectName == subjectName else { return nil }
        }

        let exists = folders.contains {
            $0.level == level
                && $0.subjectName == subjectName
                && $0.section == section
                && $0.parentFolderId == parentFolderId
                && $0.name.caseInsensitiveCompare(clean) == .orderedSame
        }
        if exists { return nil }

        let folder = ContentFolder(
            id: UUID(),
            name: clean,
            section: section,
            levelRaw: level.rawValue,
            subjectName: subjectName,
            createdAt: Date(),
            parentFolderId: parentFolderId
        )
        folders.insert(folder, at: 0)
        persistFolders()

        if usesCloud {
            Task {
                do {
                    let row = FolderInsert(
                        id: folder.id,
                        name: folder.name,
                        section: folder.section.rawValue,
                        levelRaw: folder.levelRaw,
                        subjectName: folder.subjectName,
                        createdBy: client.userId,
                        parentFolderId: folder.parentFolderId
                    )
                    let _: RemoteFolder = try await client.insert(table: "content_folders", row: row)
                } catch {
                    lastSyncError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
        return folder
    }

    func renameFolder(id: UUID, to newName: String) {
        let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        let old = folders[index]
        guard staffCanManage(subjectName: old.subjectName) else {
            lastSyncError = "You can only rename folders for your specialist subjects."
            return
        }
        folders[index] = ContentFolder(
            id: old.id,
            name: clean,
            section: old.section,
            levelRaw: old.levelRaw,
            subjectName: old.subjectName,
            createdAt: old.createdAt,
            parentFolderId: old.parentFolderId
        )
        persistFolders()

        if usesCloud {
            Task {
                struct NameOnly: Encodable { let name: String }
                try? await client.update(
                    table: "content_folders",
                    query: "id=eq.\(id.uuidString)",
                    values: NameOnly(name: clean)
                )
            }
        }
    }

    func removeFolder(id: UUID, deleteContents: Bool = false) {
        guard let folder = folders.first(where: { $0.id == id }) else { return }
        guard staffCanManage(subjectName: folder.subjectName) else {
            lastSyncError = "You can only delete folders for your specialist subjects."
            return
        }
        // Also remove nested mini-folders under this folder.
        let childIds = folders.filter { $0.parentFolderId == id }.map(\.id)
        for childId in childIds {
            removeFolder(id: childId, deleteContents: deleteContents)
        }
        folders.removeAll { $0.id == id }
        if deleteContents {
            items.removeAll { $0.folderId == id }
            persistItems()
        } else {
            items = items.map { item in
                guard item.folderId == id else { return item }
                return LibraryItem(
                    id: item.id,
                    kind: item.kind,
                    title: item.title,
                    topic: item.topic,
                    description: item.description,
                    levelRaw: item.levelRaw,
                    subjectName: item.subjectName,
                    localFilePath: item.localFilePath,
                    originalFileName: item.originalFileName,
                    createdAt: item.createdAt,
                    uploaderName: item.uploaderName,
                    folderId: nil
                )
            }
            persistItems()
        }
        persistFolders()

        if usesCloud {
            Task {
                if deleteContents {
                    try? await client.delete(table: "library_items", query: "folder_id=eq.\(id.uuidString)")
                } else {
                    struct ClearFolder: Encodable {
                        let folderId: UUID?
                        enum CodingKeys: String, CodingKey { case folderId = "folder_id" }
                    }
                    try? await client.update(
                        table: "library_items",
                        query: "folder_id=eq.\(id.uuidString)",
                        values: ClearFolder(folderId: nil)
                    )
                }
                try? await client.delete(table: "content_folders", query: "id=eq.\(id.uuidString)")
            }
        }
    }

    // MARK: - Add content

    @discardableResult
    func addDocument(
        title: String,
        topic: String,
        description: String,
        level: Level,
        subjectName: String,
        sourceURL: URL?,
        uploaderName: String,
        asNotes: Bool = false,
        folderId: UUID? = nil
    ) -> LibraryItem {
        // Sync wrapper — prefer `addDocumentAsync` when cloud is on.
        if usesCloud {
            Task {
                _ = try? await addDocumentAsync(
                    title: title,
                    topic: topic,
                    description: description,
                    level: level,
                    subjectName: subjectName,
                    sourceURL: sourceURL,
                    uploaderName: uploaderName,
                    asNotes: asNotes,
                    folderId: folderId
                )
            }
        }

        let path = copyIfPossible(sourceURL)
        let item = LibraryItem(
            id: UUID(),
            kind: asNotes ? .note : .paper,
            title: title,
            topic: topic,
            description: description,
            levelRaw: level.rawValue,
            subjectName: subjectName,
            localFilePath: path,
            originalFileName: sourceURL?.lastPathComponent ?? "document.pdf",
            createdAt: Date(),
            uploaderName: uploaderName,
            folderId: folderId
        )
        // When cloud is on, async path inserts the real row; avoid double-local insert.
        if !usesCloud {
            items.insert(item, at: 0)
            persistItems()
        }
        return item
    }

    @discardableResult
    func addDocumentAsync(
        title: String,
        topic: String,
        description: String,
        level: Level,
        subjectName: String,
        sourceURL: URL?,
        uploaderName: String,
        asNotes: Bool = false,
        folderId: UUID? = nil
    ) async throws -> LibraryItem {
        guard staffCanManage(subjectName: subjectName) else {
            throw SupabaseError.message(
                "You can only upload for your specialist subjects: \(AuthManager.shared.currentUser?.managedSubjectsDisplay ?? "—")."
            )
        }
        let id = UUID()
        let kind: LibraryContentKind = asNotes ? .note : .paper
        var storagePath: String?
        var localPath = ""
        let fileName = sourceURL?.lastPathComponent ?? "document.pdf"

        if let sourceURL {
            localPath = copyIfPossible(sourceURL)
            if usesCloud, let data = readFileData(from: sourceURL) {
                let ext = (fileName as NSString).pathExtension
                let objectPath = "\(level.rawValue)/\(subjectName)/\(kind.rawValue)/\(id.uuidString).\(ext.isEmpty ? "pdf" : ext)"
                storagePath = try await client.uploadFile(
                    bucket: SupabaseConfig.contentBucket,
                    path: objectPath,
                    data: data,
                    contentType: mimeType(for: fileName)
                )
                if let url = client.publicURL(bucket: SupabaseConfig.contentBucket, path: objectPath) {
                    localPath = url.absoluteString
                }
            }
        }

        let item = LibraryItem(
            id: id,
            kind: kind,
            title: title,
            topic: topic,
            description: description,
            levelRaw: level.rawValue,
            subjectName: subjectName,
            localFilePath: localPath,
            originalFileName: fileName,
            createdAt: Date(),
            uploaderName: uploaderName,
            folderId: folderId
        )

        if usesCloud {
            let row = LibraryItemInsert(
                id: id,
                kind: kind == .note ? "note" : "paper",
                title: title,
                topic: topic,
                description: description,
                levelRaw: level.rawValue,
                subjectName: subjectName,
                storagePath: storagePath,
                originalFileName: fileName,
                folderId: folderId,
                uploaderId: client.userId,
                uploaderName: uploaderName
            )
            let _: RemoteLibraryItem = try await client.insert(table: "library_items", row: row)
        }

        items.insert(item, at: 0)
        persistItems()
        return item
    }

    @discardableResult
    func addPaper(
        title: String,
        topic: String,
        description: String,
        level: Level,
        subjectName: String,
        sourceURL: URL?,
        uploaderName: String,
        folderId: UUID? = nil
    ) -> LibraryItem {
        addDocument(
            title: title,
            topic: topic,
            description: description,
            level: level,
            subjectName: subjectName,
            sourceURL: sourceURL,
            uploaderName: uploaderName,
            asNotes: false,
            folderId: folderId
        )
    }

    func addPaperAsync(
        title: String,
        topic: String,
        description: String,
        level: Level,
        subjectName: String,
        sourceURL: URL?,
        uploaderName: String,
        folderId: UUID? = nil
    ) async throws -> LibraryItem {
        try await addDocumentAsync(
            title: title,
            topic: topic,
            description: description,
            level: level,
            subjectName: subjectName,
            sourceURL: sourceURL,
            uploaderName: uploaderName,
            asNotes: false,
            folderId: folderId
        )
    }

    @discardableResult
    func addNote(
        title: String,
        topic: String,
        description: String,
        level: Level,
        subjectName: String,
        sourceURL: URL?,
        uploaderName: String,
        folderId: UUID? = nil
    ) -> LibraryItem {
        addDocument(
            title: title,
            topic: topic,
            description: description,
            level: level,
            subjectName: subjectName,
            sourceURL: sourceURL,
            uploaderName: uploaderName,
            asNotes: true,
            folderId: folderId
        )
    }

    func addNoteAsync(
        title: String,
        topic: String,
        description: String,
        level: Level,
        subjectName: String,
        sourceURL: URL?,
        uploaderName: String,
        folderId: UUID? = nil
    ) async throws -> LibraryItem {
        try await addDocumentAsync(
            title: title,
            topic: topic,
            description: description,
            level: level,
            subjectName: subjectName,
            sourceURL: sourceURL,
            uploaderName: uploaderName,
            asNotes: true,
            folderId: folderId
        )
    }

    @discardableResult
    func addVideo(
        title: String,
        topic: String,
        description: String,
        level: Level,
        subjectName: String,
        originalFileName: String,
        uploaderName: String,
        folderId: UUID? = nil,
        sourceURL: URL? = nil,
        videoData: Data? = nil
    ) -> LibraryItem {
        if usesCloud {
            Task {
                _ = try? await addVideoAsync(
                    title: title,
                    topic: topic,
                    description: description,
                    level: level,
                    subjectName: subjectName,
                    originalFileName: originalFileName,
                    uploaderName: uploaderName,
                    folderId: folderId,
                    sourceURL: sourceURL,
                    videoData: videoData
                )
            }
            // Placeholder until async finishes; list refreshes after insert.
            return LibraryItem(
                id: UUID(),
                kind: .video,
                title: title,
                topic: topic,
                description: description,
                levelRaw: level.rawValue,
                subjectName: subjectName,
                localFilePath: "",
                originalFileName: originalFileName,
                createdAt: Date(),
                uploaderName: uploaderName,
                folderId: folderId
            )
        }

        let localPath: String
        if let sourceURL {
            localPath = copyIfPossible(sourceURL)
        } else if let videoData {
            localPath = writeDataIfPossible(videoData, fileName: originalFileName)
        } else {
            localPath = ""
        }

        let item = LibraryItem(
            id: UUID(),
            kind: .video,
            title: title,
            topic: topic,
            description: description,
            levelRaw: level.rawValue,
            subjectName: subjectName,
            localFilePath: localPath,
            originalFileName: originalFileName,
            createdAt: Date(),
            uploaderName: uploaderName,
            folderId: folderId
        )
        items.insert(item, at: 0)
        persistItems()
        return item
    }

    func addVideoAsync(
        title: String,
        topic: String,
        description: String,
        level: Level,
        subjectName: String,
        originalFileName: String,
        uploaderName: String,
        folderId: UUID? = nil,
        sourceURL: URL? = nil,
        videoData: Data? = nil
    ) async throws -> LibraryItem {
        guard staffCanManage(subjectName: subjectName) else {
            throw SupabaseError.message(
                "You can only upload for your specialist subjects: \(AuthManager.shared.currentUser?.managedSubjectsDisplay ?? "—")."
            )
        }
        let id = UUID()
        var storagePath: String?
        var localPath = ""
        let fileName = originalFileName.isEmpty ? "lesson.mp4" : originalFileName

        // Prefer in-memory bytes (PhotosPicker); fall back to a file URL.
        let payload: Data?
        if let videoData, !videoData.isEmpty {
            payload = videoData
            localPath = writeDataIfPossible(videoData, fileName: fileName)
        } else if let sourceURL {
            localPath = copyIfPossible(sourceURL)
            payload = readFileData(from: sourceURL)
        } else {
            payload = nil
        }

        if usesCloud, let payload {
            let ext = (fileName as NSString).pathExtension
            let objectPath = "\(level.rawValue)/\(subjectName)/video/\(id.uuidString).\(ext.isEmpty ? "mp4" : ext)"
            storagePath = try await client.uploadFile(
                bucket: SupabaseConfig.contentBucket,
                path: objectPath,
                data: payload,
                contentType: mimeType(for: fileName)
            )
            if let url = client.publicURL(bucket: SupabaseConfig.contentBucket, path: objectPath) {
                localPath = url.absoluteString
            }
        }

        let item = LibraryItem(
            id: id,
            kind: .video,
            title: title,
            topic: topic,
            description: description,
            levelRaw: level.rawValue,
            subjectName: subjectName,
            localFilePath: localPath,
            originalFileName: fileName,
            createdAt: Date(),
            uploaderName: uploaderName,
            folderId: folderId
        )

        if usesCloud {
            let row = LibraryItemInsert(
                id: id,
                kind: "video",
                title: title,
                topic: topic,
                description: description,
                levelRaw: level.rawValue,
                subjectName: subjectName,
                storagePath: storagePath,
                originalFileName: fileName,
                folderId: folderId,
                uploaderId: client.userId,
                uploaderName: uploaderName
            )
            let _: RemoteLibraryItem = try await client.insert(table: "library_items", row: row)
        }

        items.insert(item, at: 0)
        persistItems()
        return item
    }

    func moveItem(id: UUID, toFolder folderId: UUID?) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items[index]
        items[index] = LibraryItem(
            id: item.id,
            kind: item.kind,
            title: item.title,
            topic: item.topic,
            description: item.description,
            levelRaw: item.levelRaw,
            subjectName: item.subjectName,
            localFilePath: item.localFilePath,
            originalFileName: item.originalFileName,
            createdAt: item.createdAt,
            uploaderName: item.uploaderName,
            folderId: folderId
        )
        persistItems()

        if usesCloud {
            Task {
                struct FolderOnly: Encodable {
                    let folderId: UUID?
                    enum CodingKeys: String, CodingKey { case folderId = "folder_id" }
                }
                try? await client.update(
                    table: "library_items",
                    query: "id=eq.\(id.uuidString)",
                    values: FolderOnly(folderId: folderId)
                )
            }
        }
    }

    func remove(id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        guard staffCanManage(subjectName: item.subjectName) else {
            lastSyncError = "You can only delete content for your specialist subjects."
            return
        }
        items.removeAll { $0.id == id }
        persistItems()
        if usesCloud {
            Task {
                try? await client.delete(table: "library_items", query: "id=eq.\(id.uuidString)")
            }
        }
    }

    private func mimeType(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "application/pdf"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        default: return "application/octet-stream"
        }
    }

    // MARK: - Persistence

    private func load() {
        loadFolders()
        loadItems()
    }

    private func loadItems() {
        if let data = defaults.data(forKey: itemsKey),
           let decoded = try? JSONDecoder().decode([LibraryItem].self, from: data) {
            items = decoded
            return
        }
        // Migrate legacy v1 store (document/video only, no folders).
        if let data = defaults.data(forKey: legacyItemsKey),
           let decoded = try? JSONDecoder().decode([LibraryItem].self, from: data) {
            items = decoded
            persistItems()
            return
        }
        items = []
    }

    private func loadFolders() {
        guard let data = defaults.data(forKey: foldersKey),
              let decoded = try? JSONDecoder().decode([ContentFolder].self, from: data) else {
            folders = []
            return
        }
        folders = decoded
    }

    private func persistItems() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: itemsKey)
    }

    private func persistFolders() {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        defaults.set(data, forKey: foldersKey)
    }

    private func copyIfPossible(_ url: URL?) -> String {
        guard let url else { return "" }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let dir = try uploadsDirectory()
            let dest = dir.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: url, to: dest)
            return dest.path
        } catch {
            return ""
        }
    }

    /// Reads file bytes with security-scoped access (required for some document/photo library URLs).
    private func readFileData(from url: URL) -> Data? {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        return try? Data(contentsOf: url)
    }

    /// Writes in-memory upload bytes (e.g. PhotosPicker video) into the app Documents folder.
    private func writeDataIfPossible(_ data: Data, fileName: String) -> String {
        guard !data.isEmpty else { return "" }
        do {
            let dir = try uploadsDirectory()
            let safeName = fileName.isEmpty ? "upload.bin" : fileName
            let dest = dir.appendingPathComponent(UUID().uuidString + "-" + safeName)
            try data.write(to: dest, options: .atomic)
            return dest.path
        } catch {
            return ""
        }
    }

    private func uploadsDirectory() throws -> URL {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "ContentLibrary", code: 1, userInfo: [NSLocalizedDescriptionKey: "Documents directory unavailable"])
        }
        let dir = docs.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
