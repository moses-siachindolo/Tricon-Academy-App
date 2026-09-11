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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 145), spacing: 10)]
    }

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
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tricon Academy Library")
                        .appFont(size: 22, weight: .bold, design: .rounded)
                        .foregroundColor(AppTheme.ink)
                    Text("Books beyond the curriculum — tech, science, business, and stories.")
                        .appFont(size: 13.5)
                        .foregroundColor(AppTheme.secondaryInk)
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
                        .frame(height: 48)
                        .background(AppTheme.iconWell)
                        .foregroundColor(AppTheme.iconGreen)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                                .stroke(AppTheme.cardLine, lineWidth: 1)
                        )
                    }
                    .buttonStyle(SoftPressStyle())
                    .padding(.horizontal, AppTheme.horizontalPadding)
                }

                LibrarySyncStatusView(store: bookStore)
                    .padding(.horizontal, AppTheme.horizontalPadding)

                if folders.allSatisfy({ $0.count == 0 }) {
                    emptyLibraryBanner
                        .padding(.horizontal, AppTheme.horizontalPadding)
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(folders) { folder in
                            NavigationLink {
                                LibraryCategoryView(category: folder.category)
                            } label: {
                                libraryFolderCard(folder.category, count: folder.count)
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .refreshable { await bookStore.refreshFromCloud() }
        .background(AppTheme.classroomWash)
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
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(AppTheme.iconGreen)
                .symbolRenderingMode(.monochrome)
            Text("Library is empty")
                .appFont(size: 15, weight: .semibold)
                .foregroundColor(AppTheme.ink)
            Text("Sample titles will appear here when available.")
                .appFont(size: 13)
                .foregroundColor(AppTheme.secondaryInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(AppTheme.cardLine, lineWidth: 1)
        )
    }

    /// Pure layout. The count is passed in — this function never reads the catalogue,
    /// so it cannot participate in a data-loading call cycle.
    private func libraryFolderCard(_ category: LibraryCategory, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.iconGreen)
                .symbolRenderingMode(.monochrome)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous)
                        .fill(AppTheme.iconWell)
                )
                .accessibilityHidden(true)

            Text(category.rawValue)
                .appFont(size: 15, weight: .semibold)
                .foregroundColor(AppTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            Text(category.blurb)
                .appFont(size: 11.5, weight: .medium)
                .foregroundColor(AppTheme.secondaryInk)
                .lineLimit(2)

            Text(count == 1 ? "1 book" : "\(count) books")
                .appFont(size: 12, weight: .medium)
                .foregroundColor(AppTheme.secondaryInk)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(AppTheme.cardLine, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.rawValue). \(category.blurb). \(count) books.")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens this library folder")
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
                HStack(spacing: 14) {
                    Image(systemName: category.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(AppTheme.iconGreen)
                        .symbolRenderingMode(.monochrome)
                        .frame(width: 52, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                                .fill(AppTheme.iconWell)
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.rawValue)
                            .appFont(size: 20, weight: .bold, design: .rounded)
                            .foregroundColor(AppTheme.ink)
                            .lineLimit(1)
                        Text(category.blurb)
                            .appFont(size: 13.5)
                            .foregroundColor(AppTheme.secondaryInk)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                        .fill(AppTheme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                        .stroke(AppTheme.cardLine, lineWidth: 1)
                )
                .padding(.horizontal, AppTheme.horizontalPadding)

                LibrarySyncStatusView(store: bookStore)
                    .padding(.horizontal, AppTheme.horizontalPadding)

                if books.isEmpty {
                    emptyState
                        .padding(.horizontal, AppTheme.horizontalPadding)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(books) { book in
                            NavigationLink {
                                LibraryBookDetailView(
                                    book: book,
                                    filePath: filePathById[book.id]
                                )
                            } label: {
                                bookRow(book)
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .refreshable { await bookStore.refreshFromCloud() }
        .background(AppTheme.classroomWash)
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            bookStore.refreshInBackground()
        }
    }

    /// Shown only when a category has no books — an empty shelf instead of a crash.
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(AppTheme.iconGreen)
                .symbolRenderingMode(.monochrome)
            Text("No books here yet")
                .appFont(size: 15, weight: .semibold)
                .foregroundColor(AppTheme.ink)
            Text("New titles are added regularly. Please check back soon.")
                .appFont(size: 13)
                .foregroundColor(AppTheme.secondaryInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(AppTheme.cardLine, lineWidth: 1)
        )
        .onAppear {
            libraryViewLog.error("Academy Library category \(category.rawValue, privacy: .public) has no books.")
        }
    }

    private func bookRow(_ book: LibraryBook) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "book.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.iconGreen)
                .symbolRenderingMode(.monochrome)
                .frame(width: 46, height: 58)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous)
                        .fill(AppTheme.iconWell)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .appFont(size: 15, weight: .semibold)
                    .foregroundColor(AppTheme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(book.author)
                    .appFont(size: 13, weight: .medium)
                    .foregroundColor(AppTheme.secondaryInk)
                Text("\(book.audience) · \(book.pages) pages")
                    .appFont(size: 12, weight: .medium)
                    .foregroundColor(AppTheme.secondaryInk)
            }

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.secondaryInk)
        }
        .padding(16)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(AppTheme.cardLine, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(book.title), \(book.author), \(book.audience), \(book.pages) pages")
        .accessibilityAddTraits(.isButton)
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
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(AppTheme.iconGreen)
                        .symbolRenderingMode(.monochrome)
                        .frame(width: 88, height: 118)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                                .fill(AppTheme.iconWell)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                                .stroke(AppTheme.cardLine, lineWidth: 1)
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(book.title)
                            .appFont(size: 20, weight: .bold, design: .rounded)
                            .foregroundColor(AppTheme.ink)
                        Text(book.author)
                            .appFont(size: 15, weight: .medium)
                            .foregroundColor(AppTheme.secondaryInk)
                        Text(book.category.rawValue)
                            .appFont(size: 12, weight: .semibold)
                            .foregroundColor(AppTheme.iconGreen)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(AppTheme.iconWell))
                    }
                    .padding(.top, 4)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                        .fill(AppTheme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                        .stroke(AppTheme.cardLine, lineWidth: 1)
                )

                HStack(spacing: 10) {
                    metaChip(icon: "person.fill", text: book.audience)
                    metaChip(icon: "doc.text.fill", text: "\(book.pages) pages")
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
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("About this book")
                        .appFont(size: 16, weight: .bold)
                        .foregroundColor(AppTheme.ink)
                    Text(book.summary.isEmpty ? "No summary provided." : book.summary)
                        .appFont(size: 15)
                        .foregroundColor(AppTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                        .fill(AppTheme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                        .stroke(AppTheme.cardLine, lineWidth: 1)
                )
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(AppTheme.classroomWash)
        .navigationTitle("Book")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .symbolRenderingMode(.monochrome)
            Text(text)
                .appFont(size: 12.5, weight: .medium)
        }
        .foregroundColor(AppTheme.iconGreen)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Capsule().fill(AppTheme.iconWell))
        .overlay(Capsule().stroke(AppTheme.cardLine, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

struct TriconAcademyLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TriconAcademyLibraryView()
        }
    }
}

private struct LibrarySyncStatusView: View {
    @ObservedObject var store: LibraryBookStore

    var body: some View {
        if store.lastError != nil {
            VStack(alignment: .leading, spacing: 10) {
                Label("Library could not refresh", systemImage: "wifi.exclamationmark")
                    .font(.headline)
                    .foregroundColor(AppTheme.ink)
                Text("Showing available books. Check your connection and try again.")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.secondaryInk)
                Button("Try again") { store.refreshInBackground() }
                    .buttonStyle(AppSecondaryButtonStyle())
                    .disabled(store.isRefreshing)
            }
            .padding(16)
            .appCard(elevated: false)
        } else if store.isRefreshing {
            ProgressView("Updating library…")
                .frame(maxWidth: .infinity, alignment: .leading)
                .tint(AppTheme.brand)
        }
    }
}
