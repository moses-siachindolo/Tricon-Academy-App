import SwiftUI
import PDFKit
import UIKit
import CryptoKit

struct PDFViewerScreen: View {

    let fileName: String
    let title: String
    /// Only "Past Papers" should count toward the "Papers solved" stat —
    /// Materials reuse this same viewer but shouldn't be counted as papers.
    var isPastPaper: Bool = true
    var contentId: String = ""
    var subjectName: String = ""
    var levelRaw: String = ""
    var year: Int? = nil
    var topic: String = ""

    @ObservedObject private var saved = SavedItemsManager.shared
    @State private var hasRecordedOpen = false
    @State private var loadedDocument: PDFDocument?
    @State private var remoteLoadFailed = false
    @State private var isDownloading = false

    private var resolvedURL: URL? {
        // Absolute path from local uploads
        if fileName.hasPrefix("/") {
            let url = URL(fileURLWithPath: fileName)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        // Bundle PDF
        if let bundle = Bundle.main.url(forResource: fileName, withExtension: "pdf") {
            return bundle
        }
        // Bundle without assuming extension in name
        if fileName.lowercased().hasSuffix(".pdf"),
           let bundle = Bundle.main.url(forResource: (fileName as NSString).deletingPathExtension, withExtension: "pdf") {
            return bundle
        }
        return nil
    }

    private var isRemoteFile: Bool {
        fileName.hasPrefix("http://") || fileName.hasPrefix("https://")
    }

    private var isBookmarked: Bool {
        !contentId.isEmpty && saved.isSaved(id: contentId)
    }

    var body: some View {
        Group {
            if let document = loadedDocument, !remoteLoadFailed {
                PDFKitView(document: document)
            } else {
                loadingOrError
            }
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !contentId.isEmpty {
                    Button {
                        toggleBookmark()
                    } label: {
                        AppIconLabel(systemName: isBookmarked ? "bookmark.fill" : "bookmark",
                                     tint: isBookmarked ? AppTheme.bookmark : AppTheme.brandDeep)
                    }
                    .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Save")
                }
            }
        }
        .task(id: fileName) {
            loadedDocument = nil
            hasRecordedOpen = false
            await loadDocument()
        }
    }

    private func recordSuccessfulOpen() {
        guard !hasRecordedOpen else { return }
        hasRecordedOpen = true
        if isPastPaper {
            StatsManager.shared.recordPaperOpened()
        } else {
            StatsManager.shared.recordNotesOpened()
        }
        StatsManager.shared.recordResourceOpened(
            id: contentId, subject: subjectName, title: title,
            kind: isPastPaper ? .paper : .notes, levelRaw: levelRaw
        )
    }

    private var loadingOrError: some View {
        VStack(spacing: 14) {
            if remoteLoadFailed {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .foregroundColor(AppTheme.danger)
                Text(isRemoteFile ? "Could not load document" : "Document unavailable")
                    .appFont(size: 15, weight: .semibold)
                    .foregroundColor(AppTheme.ink)
                Text(isRemoteFile ? "Check your connection and try again." : "This document is missing or unreadable. Please ask your tutor to upload it again.")
                    .appFont(size: 13)
                    .foregroundColor(AppTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                if isRemoteFile {
                    Button("Try again") {
                        Task { await loadDocument() }
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                    .padding(.horizontal, 24)
                }
            } else {
                ProgressView()
                    .tint(AppTheme.brand)
                Text(isRemoteFile ? "Downloading document…" : "Preparing document…")
                    .appFont(size: 14, weight: .medium)
                    .foregroundColor(AppTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func loadDocument() async {
        guard loadedDocument == nil, !isDownloading else { return }
        isDownloading = true
        remoteLoadFailed = false
        defer { isDownloading = false }
        do {
            let document: PDFDocument
            if isRemoteFile, let remote = URL(string: fileName) {
                let request = SupabaseConfig.isConfigured
                    ? SupabaseClient.shared.documentDownloadRequest(from: remote)
                    : URLRequest(url: remote)
                document = try await DocumentDownloadCache.shared.document(for: request)
            } else if let url = resolvedURL {
                document = try await DocumentDownloadCache.shared.localDocument(at: url)
            } else {
                throw URLError(.fileDoesNotExist)
            }
            try Task.checkCancellation()
            loadedDocument = document
            recordSuccessfulOpen()
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled { remoteLoadFailed = true }
        }
    }

    private func toggleBookmark() {
        guard !contentId.isEmpty else { return }
        let level = Level(rawValue: levelRaw) ?? .form1
        if isPastPaper {
            saved.togglePaper(
                PastPaper(
                    id: contentId,
                    title: title,
                    year: year ?? Calendar.current.component(.year, from: Date()),
                    fileName: fileName,
                    level: level,
                    subjectName: subjectName
                )
            )
        } else {
            saved.toggleMaterial(
                StudyMaterial(
                    id: contentId,
                    title: title,
                    topic: topic.isEmpty ? "Study notes" : topic,
                    fileName: fileName,
                    level: level,
                    subjectName: subjectName
                )
            )
        }
    }
}

// MARK: - PDFKit bridge

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor.systemGroupedBackground
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document !== document {
            uiView.document = document
        }
    }
}

/// Shared by papers, notes, saved items and library books. File and PDF work
/// stays on this actor rather than blocking scrolling on the main actor.
actor DocumentDownloadCache {
    static let shared = DocumentDownloadCache()

    private let directory: URL
    private let session: URLSession
    private var downloads: [String: Task<URL, Error>] = [:]
    private let lifetime: TimeInterval = 7 * 24 * 60 * 60
    private let sizeLimit = 250 * 1024 * 1024

    init(directory: URL? = nil, session: URLSession = .shared) {
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Documents", isDirectory: true)
        self.session = session
    }

    func localDocument(at url: URL) throws -> PDFDocument {
        guard let document = PDFDocument(url: url), document.pageCount > 0 else {
            throw URLError(.cannotDecodeContentData)
        }
        return document
    }

    func document(for request: URLRequest) async throws -> PDFDocument {
        guard let url = request.url else { throw URLError(.badURL) }
        // Include credentials in the hash so private responses never cross sessions.
        let identity = url.absoluteString + "\n" + (request.value(forHTTPHeaderField: "Authorization") ?? "")
            + "\n" + (request.value(forHTTPHeaderField: "apikey") ?? "")
        let key = SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
        let destination = directory.appendingPathComponent(key + ".pdf")
        if let attributes = try? FileManager.default.attributesOfItem(atPath: destination.path),
           let created = attributes[.creationDate] as? Date,
           Date().timeIntervalSince(created) < lifetime,
           let document = try? localDocument(at: destination) {
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: destination.path)
            return document
        }
        if let download = downloads[key] {
            return try localDocument(at: await download.value)
        }
        let download = Task {
            try await self.download(request, to: destination)
        }
        downloads[key] = download
        defer { downloads[key] = nil }
        let file = try await download.value
        return try localDocument(at: file)
    }

    private func download(_ request: URLRequest, to destination: URL) async throws -> URL {
        // Stream to disk instead of holding the entire download in a Data buffer.
        let (temporaryURL, response) = try await session.download(for: request)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        // Never persist an error page or a corrupt document as a successful download.
        _ = try localDocument(at: temporaryURL)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        prune(excluding: destination)
        return destination
    }

    private func prune(excluding current: URL) {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey, .creationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: Array(keys), options: .skipsHiddenFiles
        ) else { return }
        let entries = files.compactMap { url -> (url: URL, size: Int, accessed: Date, created: Date)? in
            guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast,
                    values.creationDate ?? .distantPast)
        }.sorted { $0.accessed < $1.accessed }
        var total = entries.reduce(0) { $0 + $1.size }
        for entry in entries where entry.url != current {
            if total > sizeLimit || Date().timeIntervalSince(entry.created) >= lifetime {
                if (try? FileManager.default.removeItem(at: entry.url)) != nil {
                    total -= entry.size
                }
            }
        }
    }
}
