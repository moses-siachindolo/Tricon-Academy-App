import SwiftUI
import os

// MARK: - Tricon Academy Library (fully offline browse)
// No network calls when opening or browsing. Sample catalogue only.
// Server issues cannot freeze or crash this screen.
// This screen never force-unwraps, never subscripts by index, and reads the
// catalogue through `TriconAcademyLibrary`'s cached, non-recursive accessors only.

private let libraryViewLog = Logger(subsystem: "com.tricon.academy", category: "LibraryView")

struct TriconAcademyLibraryView: View {

    @ObservedObject private var bookStore = LibraryBookStore.shared
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showUploadBook = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private struct Folder: Identifiable, Hashable {
        let category: LibraryCategory
        let count: Int
        var id: String { category.id }
    }

    /// Sample catalogue + admin-approved staff uploads (pending tutor books stay hidden).
    private var folders: [Folder] {
        LibraryCategory.allCases.map { category in
            let sample = TriconAcademyLibrary.sampleBookCount(in: category)
            let approved = bookStore.approvedBooks(in: category).count
            return Folder(category: category, count: sample + approved)
        }
    }

    private var canSubmitBooks: Bool {
        authManager.currentUser?.canManageContent == true
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tricon Academy Library")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.ink)
                    Text("Books beyond the curriculum — tech, science, business, and stories.")
                        .font(.system(size: 13.5))
                        .foregroundColor(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, AppTheme.horizontalPadding)

                if canSubmitBooks {
                    Button {
                        showUploadBook = true
                    } label: {
                        Label(
                            authManager.currentUser?.isAdmin == true
                                ? "Upload library book"
                                : "Submit a book for admin review",
                            systemImage: "plus.circle.fill"
                        )
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(AppTheme.brandSoft)
                        .foregroundColor(AppTheme.brandDeep)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppTheme.horizontalPadding)
                }

                if folders.allSatisfy({ $0.count == 0 }) {
                    emptyLibraryBanner
                        .padding(.horizontal, AppTheme.horizontalPadding)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(folders) { folder in
                            NavigationLink {
                                LibraryCategoryView(category: folder.category)
                            } label: {
                                libraryFolderCard(folder.category, count: folder.count)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Offline sample catalogue first; approved uploads merge when available.
            TriconAcademyLibrary.preload()
            bookStore.refreshInBackground()
        }
        .sheet(isPresented: $showUploadBook) {
            UploadLibraryBookView()
                .environmentObject(authManager)
        }
    }

    private var emptyLibraryBanner: some View {
        VStack(spacing: 8) {
            Image(systemName: "books.vertical")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(AppTheme.brandDeep.opacity(0.7))
            Text("Library is empty")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.ink)
            Text("Sample titles will appear here when available.")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }

    /// Pure layout. The count is passed in — this function never reads the catalogue,
    /// so it cannot participate in a data-loading call cycle.
    private func libraryFolderCard(_ category: LibraryCategory, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(category.accent.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: category.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(category.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(category.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                Text(category.blurb)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(AppTheme.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack {
                Text("\(count) books")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(category.accent)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.subtle)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 3)
    }
}

// MARK: - Books in a category

struct LibraryCategoryView: View {
    let category: LibraryCategory

    @ObservedObject private var bookStore = LibraryBookStore.shared

    /// Sample titles plus admin-approved staff uploads only.
    private var books: [LibraryBook] {
        let samples = TriconAcademyLibrary.sampleBooks(in: category)
        let uploaded = bookStore.approvedBooks(in: category).map(\.asDisplayBook)
        // Prefer uploaded books first so new staff content is easy to find.
        var seen = Set<String>()
        var result: [LibraryBook] = []
        for book in uploaded + samples {
            if seen.insert(book.id).inserted {
                result.append(book)
            }
        }
        return result
    }

    /// Map display book id → optional PDF path for staff uploads.
    private var filePathById: [String: String] {
        Dictionary(
            uniqueKeysWithValues: bookStore.approvedBooks(in: category).map {
                ($0.id.uuidString, $0.filePath)
            }
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.rawValue)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.ink)
                    Text(category.blurb)
                        .font(.system(size: 13.5))
                        .foregroundColor(AppTheme.muted)
                }
                .padding(.horizontal, AppTheme.horizontalPadding)

                if books.isEmpty {
                    emptyState
                        .padding(.horizontal, AppTheme.horizontalPadding)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(books) { book in
                            NavigationLink {
                                LibraryBookDetailView(
                                    book: book,
                                    filePath: filePathById[book.id]
                                )
                            } label: {
                                bookRow(book)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            bookStore.refreshInBackground()
        }
    }

    /// Shown only when a category has no books — an empty shelf instead of a crash.
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "books.vertical")
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(category.accent.opacity(0.7))
            Text("No books here yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.ink)
            Text("New titles are added regularly. Please check back soon.")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
        .onAppear {
            libraryViewLog.error("Academy Library category \(category.rawValue, privacy: .public) has no books.")
        }
    }

    private func bookRow(_ book: LibraryBook) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(category.accent.opacity(0.14))
                    .frame(width: 52, height: 68)
                Image(systemName: "book.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(category.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                    .lineLimit(2)
                Text(book.author)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.muted)
                Text("\(book.audience) · \(book.pages) pages")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.muted.opacity(0.9))
            }

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.subtle)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow, radius: 6, x: 0, y: 2)
    }
}

// MARK: - Book detail

struct LibraryBookDetailView: View {
    let book: LibraryBook
    /// Local path or remote URL for staff-uploaded PDFs (samples have no file).
    var filePath: String? = nil

    private var hasReadableFile: Bool {
        guard let filePath, !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return true
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(book.category.accent.opacity(0.14))
                            .frame(width: 88, height: 118)
                        Image(systemName: "book.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(book.category.accent)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(book.title)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.ink)
                        Text(book.author)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.muted)
                        Text(book.category.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(book.category.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(book.category.accent.opacity(0.12)))
                    }
                    .padding(.top, 4)
                }

                HStack(spacing: 10) {
                    metaChip(icon: "person.fill", text: book.audience)
                    metaChip(icon: "doc.text", text: "\(book.pages) pages")
                }

                if hasReadableFile, let filePath {
                    NavigationLink {
                        PDFViewerScreen(
                            fileName: filePath,
                            title: book.title,
                            isPastPaper: false,
                            contentId: book.id,
                            subjectName: "Library",
                            levelRaw: "",
                            topic: book.category.rawValue
                        )
                    } label: {
                        Label("Open PDF", systemImage: "doc.richtext.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.brand, AppTheme.brandDeep],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("About this book")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.ink)
                    Text(book.summary.isEmpty ? "No summary provided." : book.summary)
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("Book")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12.5, weight: .medium))
        }
        .foregroundColor(AppTheme.ink.opacity(0.85))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(AppTheme.card))
        .overlay(Capsule().stroke(AppTheme.stroke, lineWidth: 1))
    }
}

struct TriconAcademyLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TriconAcademyLibraryView()
        }
    }
}
