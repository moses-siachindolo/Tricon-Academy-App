import Foundation
import Combine

// MARK: - User-uploaded Academy Library books (optional cloud sync)

enum LibraryBookApproval: String, Codable {
    case pending
    case approved
    case rejected
}

struct UserLibraryBook: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var author: String
    var summary: String
    var categoryRaw: String
    var audience: String
    var pages: Int
    var uploaderId: UUID?
    var uploaderName: String
    var approvalStatus: LibraryBookApproval
    var reviewReason: String?
    var filePath: String
    var originalFileName: String
    var createdAt: Date

    var category: LibraryCategory {
        LibraryCategory.from(rawValue: categoryRaw)
    }

    var asDisplayBook: LibraryBook {
        LibraryBook(
            id: id.uuidString,
            title: title,
            author: author,
            summary: summary,
            category: category,
            audience: audience,
            pages: pages
        )
    }
}

/// Tolerant row decoder: every optional/missing column falls back to a safe default
/// so a partially-populated Supabase response can never throw or crash the library.
struct RemoteUserLibraryBook: Codable, Identifiable {
    let id: UUID
    var title: String
    var author: String
    var summary: String
    var categoryRaw: String
    var audience: String
    var pages: Int
    var uploaderId: UUID?
    var uploaderName: String
    var approvalStatus: String
    var reviewReason: String?
    var storagePath: String?
    var originalFileName: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, author, summary, audience, pages
        case categoryRaw = "category_raw"
        case uploaderId = "uploader_id"
        case uploaderName = "uploader_name"
        case approvalStatus = "approval_status"
        case reviewReason = "review_reason"
        case storagePath = "storage_path"
        case originalFileName = "original_file_name"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        func optional<T: Decodable>(_ type: T.Type, _ key: CodingKeys) -> T? {
            guard let value = try? c.decodeIfPresent(type, forKey: key) else { return nil }
            return value
        }

        // `id` is the only genuinely required column; a row without one is unusable.
        id = try c.decode(UUID.self, forKey: .id)
        title = optional(String.self, .title) ?? "Untitled"
        author = optional(String.self, .author) ?? "Unknown author"
        summary = optional(String.self, .summary) ?? ""
        categoryRaw = optional(String.self, .categoryRaw) ?? LibraryCategory.science.rawValue
        audience = optional(String.self, .audience) ?? "All levels"
        pages = max(optional(Int.self, .pages) ?? 1, 1)
        uploaderId = optional(UUID.self, .uploaderId)
        uploaderName = optional(String.self, .uploaderName) ?? ""
        approvalStatus = optional(String.self, .approvalStatus) ?? LibraryBookApproval.pending.rawValue
        reviewReason = optional(String.self, .reviewReason)
        storagePath = optional(String.self, .storagePath)
        originalFileName = optional(String.self, .originalFileName) ?? ""
        createdAt = optional(Date.self, .createdAt)
    }

    var asUserLibraryBook: UserLibraryBook {
        let path: String
        if let storagePath = storagePath, !storagePath.isEmpty,
           let url = SupabaseClient.shared.publicURL(bucket: SupabaseConfig.contentBucket, path: storagePath) {
            path = url.absoluteString
        } else {
            path = ""
        }
        return UserLibraryBook(
            id: id,
            title: title,
            author: author,
            summary: summary,
            categoryRaw: categoryRaw,
            audience: audience,
            pages: max(pages, 1),
            uploaderId: uploaderId,
            uploaderName: uploaderName,
            approvalStatus: LibraryBookApproval(rawValue: approvalStatus) ?? .pending,
            reviewReason: reviewReason,
            filePath: path,
            originalFileName: originalFileName,
            createdAt: createdAt ?? Date()
        )
    }
}

struct UserLibraryBookInsert: Encodable {
    let id: UUID
    let title: String
    let author: String
    let summary: String
    let categoryRaw: String
    let audience: String
    let pages: Int
    let uploaderId: UUID?
    let uploaderName: String
    let approvalStatus: String
    let storagePath: String?
    let originalFileName: String

    enum CodingKeys: String, CodingKey {
        case id, title, author, summary, audience, pages
        case categoryRaw = "category_raw"
        case uploaderId = "uploader_id"
        case uploaderName = "uploader_name"
        case approvalStatus = "approval_status"
        case storagePath = "storage_path"
        case originalFileName = "original_file_name"
    }
}

/// Local-first book store. UI state is main-actor isolated (same as `ContentLibrary`).
@MainActor
final class LibraryBookStore: ObservableObject {
    static let shared = LibraryBookStore()

    @Published private(set) var books: [UserLibraryBook] = []
    @Published private(set) var lastError: String?

    private let defaults = UserDefaults.standard
    private let key = "library.user.books.v1"
    private let client = SupabaseClient.shared
    @Published private(set) var isRefreshing = false

    private init() {
        load()
    }

    var approvedBooks: [UserLibraryBook] {
        books.filter { $0.approvalStatus == .approved }
    }

    var pendingBooks: [UserLibraryBook] {
        books.filter { $0.approvalStatus == .pending }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func approvedBooks(in category: LibraryCategory) -> [UserLibraryBook] {
        approvedBooks.filter { $0.category == category }
    }

    /// Books submitted by a specific staff member (any approval status).
    func books(uploadedBy uploaderId: UUID) -> [UserLibraryBook] {
        books.filter { $0.uploaderId == uploaderId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Pending count for admin badge / home tips.
    var pendingReviewCount: Int {
        pendingBooks.count
    }

    /// Non-blocking cloud sync. Safe to call from `onAppear`.
    func refreshInBackground() {
        Task { await refreshFromCloud() }
    }

    /// Pull library books from Supabase. Same main-actor pattern as `ContentLibrary`.
    func refreshFromCloud() async {
        guard client.isConfigured, client.currentSession != nil else { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            // Short timeout so a dead server cannot hang the app.
            let rows: [RemoteUserLibraryBook] = try await withThrowingTaskGroup(of: [RemoteUserLibraryBook].self) { group in
                group.addTask {
                    try await SupabaseClient.shared.select(
                        table: "library_books",
                        query: "select=*&order=created_at.desc"
                    )
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 4_000_000_000) // 4s
                    throw SupabaseError.message("Library sync timed out — showing cached books.")
                }
                guard let first = try await group.next() else {
                    throw SupabaseError.message("Library sync timed out — showing cached books.")
                }
                group.cancelAll()
                return first
            }
            books = rows.map(\.asUserLibraryBook)
            persist()
            lastError = nil
        } catch {
            // Keep existing local books; do not clear UI.
            // Timeouts and network failures are non-fatal.
            if !Task.isCancelled {
                lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    /// Submit a library book. Tutors always create `.pending` rows; only admins
    /// may pass `autoApprove: true` so the book is published without review.
    @discardableResult
    func submitBook(
        title: String,
        author: String,
        summary: String,
        category: LibraryCategory,
        audience: String,
        pages: Int,
        fileURL: URL?,
        uploaderId: UUID?,
        uploaderName: String,
        autoApprove: Bool = false
    ) -> UserLibraryBook? {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !a.isEmpty else { return nil }

        // Only admins may skip the review queue (`AuthManager` is @MainActor).
        let isAdmin = AuthManager.shared.currentUser?.isAdmin == true
        let status: LibraryBookApproval = (autoApprove && isAdmin) ? .approved : .pending

        var localPath = ""
        let originalFileName = fileURL?.lastPathComponent ?? ""
        if let fileURL, let copied = try? copyFile(fileURL) {
            localPath = copied.path
        }

        let book = UserLibraryBook(
            id: UUID(),
            title: t,
            author: a,
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryRaw: category.rawValue,
            audience: audience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "All levels" : audience,
            pages: max(pages, 1),
            uploaderId: uploaderId,
            uploaderName: uploaderName,
            approvalStatus: status,
            reviewReason: nil,
            filePath: localPath,
            originalFileName: originalFileName,
            createdAt: Date()
        )

        // Local save first so the app never depends on the server for submit success.
        books.insert(book, at: 0)
        persist()

        // Optional cloud push in background (values captured; no MainActor hop needed for network).
        if client.isConfigured, client.currentSession != nil {
            let fileNameForUpload = originalFileName
            let sourceURL = fileURL
            let snapshot = book
            Task {
                var storagePath: String?
                if let sourceURL {
                    let accessed = sourceURL.startAccessingSecurityScopedResource()
                    defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }
                    if let data = try? Data(contentsOf: sourceURL) {
                        let path = "library_books/\(snapshot.id.uuidString)/\(fileNameForUpload.isEmpty ? "book.pdf" : fileNameForUpload)"
                        try? await SupabaseClient.shared.uploadFile(
                            bucket: SupabaseConfig.contentBucket,
                            path: path,
                            data: data,
                            contentType: "application/pdf"
                        )
                        storagePath = path
                    }
                }
                let row = UserLibraryBookInsert(
                    id: snapshot.id,
                    title: snapshot.title,
                    author: snapshot.author,
                    summary: snapshot.summary,
                    categoryRaw: snapshot.categoryRaw,
                    audience: snapshot.audience,
                    pages: snapshot.pages,
                    uploaderId: uploaderId,
                    uploaderName: uploaderName,
                    approvalStatus: snapshot.approvalStatus.rawValue,
                    storagePath: storagePath,
                    originalFileName: fileNameForUpload
                )
                _ = try? await SupabaseClient.shared.insert(table: "library_books", row: row) as RemoteUserLibraryBook
            }
        }
        return book
    }

    /// Admin-only: approve or reject a pending library book.
    func setApproval(id: UUID, status: LibraryBookApproval, reason: String? = nil) {
        guard AuthManager.shared.currentUser?.isAdmin == true else {
            lastError = "Only admins can approve or reject library books."
            return
        }
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].approvalStatus = status
        books[index].reviewReason = reason
        persist()

        if client.isConfigured, client.currentSession != nil {
            let approvalRaw = status.rawValue
            Task {
                struct Patch: Encodable {
                    let approvalStatus: String
                    let reviewReason: String?
                    enum CodingKeys: String, CodingKey {
                        case approvalStatus = "approval_status"
                        case reviewReason = "review_reason"
                    }
                }
                try? await SupabaseClient.shared.update(
                    table: "library_books",
                    query: "id=eq.\(id.uuidString)",
                    values: Patch(approvalStatus: approvalRaw, reviewReason: reason)
                )
            }
        }
    }

    /// Admin-only: remove a book from the library (local + cloud).
    func removeBook(id: UUID) {
        guard AuthManager.shared.currentUser?.isAdmin == true else {
            lastError = "Only admins can delete library books."
            return
        }
        books.removeAll { $0.id == id }
        persist()
        if client.isConfigured, client.currentSession != nil {
            Task {
                try? await SupabaseClient.shared.delete(
                    table: "library_books",
                    query: "id=eq.\(id.uuidString)"
                )
            }
        }
    }

    private func copyFile(_ url: URL) throws -> URL {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "LibraryBookStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Documents directory unavailable"])
        }
        let dir = docs.appendingPathComponent("LibraryBooks", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: url, to: dest)
        return dest
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([UserLibraryBook].self, from: data) else {
            books = []
            return
        }
        books = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(books) else { return }
        defaults.set(data, forKey: key)
    }
}
