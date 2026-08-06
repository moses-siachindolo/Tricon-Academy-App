import SwiftUI
import os

// MARK: - Tricon Academy Library (Home-only reading shelf)

private let libraryLog = Logger(subsystem: "com.tricon.academy", category: "Library")

enum LibraryCategory: String, CaseIterable, Identifiable, Hashable {
    case tech = "Tech"
    case science = "Science"
    case business = "Business"
    case literature = "Literature & Stories"

    var id: String { rawValue }

    /// Safe fallback so an unknown/blank stored value can never produce `nil`.
    static func from(rawValue: String?) -> LibraryCategory {
        guard let raw = rawValue,
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let match = LibraryCategory(rawValue: raw) else {
            return .science
        }
        return match
    }

    var icon: String {
        switch self {
        case .tech: return "desktopcomputer"
        case .science: return "atom"
        case .business: return "chart.line.uptrend.xyaxis"
        case .literature: return "text.book.closed.fill"
        }
    }

    var colorName: String {
        switch self {
        case .tech: return "blue"
        case .science: return "green"
        case .business: return "indigo"
        case .literature: return "purple"
        }
    }

    var blurb: String {
        switch self {
        case .tech: return "Computing, coding & digital skills"
        case .science: return "Physics, biology, chemistry & more"
        case .business: return "Finance, leadership & entrepreneurship"
        case .literature: return "Novels, poetry & short stories"
        }
    }

    var accent: Color {
        switch colorName {
        case "blue": return Color(red: 0.20, green: 0.48, blue: 0.92)
        case "green": return Color(red: 0.10, green: 0.68, blue: 0.42)
        case "indigo": return Color(red: 0.35, green: 0.36, blue: 0.84)
        case "purple": return Color(red: 0.52, green: 0.32, blue: 0.88)
        default: return AppTheme.brand
        }
    }
}

struct LibraryBook: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let summary: String
    let category: LibraryCategory
    /// Approximate reading level / audience label
    let audience: String
    let pages: Int
}

/// Built-in sample catalogue.
///
/// Root cause of the Tutor Library trap: chained `static let catalogue` +
/// `static let catalogueByCategory` are **not re-entrant**. Opening Library makes
/// SwiftUI evaluate `NavigationLink` destinations while the first static is still
/// initializing → recursive static init, debugger stops inside `techBooks()`.
///
/// Fix: one manually-cached store, pure builders (no self-access), safe under
/// re-entrant reads from view bodies / NavigationLink.
enum TriconAcademyLibrary {

    private struct Store {
        let books: [LibraryBook]
        let byCategory: [LibraryCategory: [LibraryBook]]
    }

    /// Manual cache (not `static let` initializer) so a re-entrant read during the
    /// first build cannot re-enter Swift's static-init lock.
    private static var cachedStore: Store?

    private static func store() -> Store {
        if let cachedStore { return cachedStore }
        let books = buildCatalogue()
        let built = Store(
            books: books,
            byCategory: Dictionary(grouping: books, by: \.category)
        )
        cachedStore = built
        return built
    }

    /// Warm the catalogue once (e.g. when Home appears) so the first Library open
    /// never builds books mid-NavigationLink evaluation.
    static func preload() {
        _ = store()
    }

    static var sampleBooks: [LibraryBook] { store().books }

    /// Always returns a valid (possibly empty) array — never throws, never traps.
    static func sampleBooks(in category: LibraryCategory) -> [LibraryBook] {
        store().byCategory[category] ?? []
    }

    static func sampleBookCount(in category: LibraryCategory) -> Int {
        store().byCategory[category]?.count ?? 0
    }

    // MARK: Catalogue assembly (pure — never calls store() / sampleBooks)

    private static func buildCatalogue() -> [LibraryBook] {
        let all = techBooks() + scienceBooks() + businessBooks() + literatureBooks()
        guard !all.isEmpty else { return [] }

        var seen = Set<String>()
        let cleaned = all.filter { book in
            let id = book.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty else { return false }
            guard !book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            return seen.insert(id).inserted
        }

        libraryLog.info("Academy Library catalogue ready: \(cleaned.count, privacy: .public) books.")
        return cleaned
    }

    // MARK: Tech

    private static func techBooks() -> [LibraryBook] {
        [
            LibraryBook(
                id: "tech-1",
                title: "Think Like a Coder",
                author: "Tricon Editors",
                summary: "A friendly introduction to computational thinking, algorithms, and how software shapes the modern world — written for secondary students.",
                category: .tech,
                audience: "Forms 1-4",
                pages: 168
            ),
            LibraryBook(
                id: "tech-2",
                title: "The Internet Explained",
                author: "A. Mwanza",
                summary: "How data moves across networks, what the cloud is, and how to stay safe online. Clear diagrams and practical tips.",
                category: .tech,
                audience: "All levels",
                pages: 142
            ),
            LibraryBook(
                id: "tech-3",
                title: "Apps, AI & You",
                author: "N. Chisanga",
                summary: "A practical guide to artificial intelligence, machine learning basics, and how students can use digital tools responsibly.",
                category: .tech,
                audience: "Forms 3-4",
                pages: 190
            ),
            LibraryBook(
                id: "tech-4",
                title: "Build Your First Website",
                author: "Tricon Tech Lab",
                summary: "HTML, CSS, and simple JavaScript projects you can try at home — no prior experience required.",
                category: .tech,
                audience: "Forms 2-4",
                pages: 210
            )
        ]
    }

    // MARK: Science

    private static func scienceBooks() -> [LibraryBook] {
        [
            LibraryBook(
                id: "sci-1",
                title: "Wonders of the Universe",
                author: "Dr. L. Banda",
                summary: "Stars, planets, and the big questions of cosmology explained in plain language for curious learners.",
                category: .science,
                audience: "Forms 2-4",
                pages: 176
            ),
            LibraryBook(
                id: "sci-2",
                title: "Life on Earth",
                author: "S. Phiri",
                summary: "Cells, ecosystems, and human biology with real-world examples from African environments.",
                category: .science,
                audience: "Forms 1-3",
                pages: 204
            ),
            LibraryBook(
                id: "sci-3",
                title: "Chemistry in Daily Life",
                author: "K. Mulenga",
                summary: "From soap to batteries — the chemistry behind everyday materials, written for exam-focused students.",
                category: .science,
                audience: "Forms 3-4",
                pages: 158
            ),
            LibraryBook(
                id: "sci-4",
                title: "Forces & Motion Made Simple",
                author: "Tricon Science",
                summary: "Newton's laws, energy, and waves with step-by-step examples and practice questions.",
                category: .science,
                audience: "Forms 2-4",
                pages: 184
            )
        ]
    }

    // MARK: Business

    private static func businessBooks() -> [LibraryBook] {
        [
            LibraryBook(
                id: "biz-1",
                title: "Young Entrepreneur",
                author: "C. Daka",
                summary: "How to spot opportunities, budget simply, and start a small project — from school clubs to side hustles.",
                category: .business,
                audience: "Forms 3-4",
                pages: 172
            ),
            LibraryBook(
                id: "biz-2",
                title: "Money Sense",
                author: "Tricon Business Desk",
                summary: "Saving, spending, and basic financial literacy every student should know before leaving school.",
                category: .business,
                audience: "All levels",
                pages: 120
            ),
            LibraryBook(
                id: "biz-3",
                title: "Markets & Trade",
                author: "J. Hachali",
                summary: "Supply, demand, and how local and global markets connect — ideal for commerce students.",
                category: .business,
                audience: "Forms 3-4",
                pages: 196
            ),
            LibraryBook(
                id: "biz-4",
                title: "Lead with Clarity",
                author: "A. Sinkala",
                summary: "Teamwork, communication, and decision-making skills for prefects, club leaders, and future managers.",
                category: .business,
                audience: "Form 4",
                pages: 154
            )
        ]
    }

    // MARK: Literature & Stories

    private static func literatureBooks() -> [LibraryBook] {
        [
            LibraryBook(
                id: "lit-1",
                title: "Under the Mango Tree",
                author: "F. Nyirenda",
                summary: "A coming-of-age novel set in a Zambian town — friendship, ambition, and finding your voice.",
                category: .literature,
                audience: "Forms 2-4",
                pages: 228
            ),
            LibraryBook(
                id: "lit-2",
                title: "Whispers of the Zambezi",
                author: "R. Sichone",
                summary: "Short stories of courage and humour along the river, perfect for English literature discussion.",
                category: .literature,
                audience: "Forms 1-3",
                pages: 164
            ),
            LibraryBook(
                id: "lit-3",
                title: "Poetry for Young Voices",
                author: "Tricon Anthology",
                summary: "Accessible poems about school, home, nature, and dreams — with notes for classroom reading.",
                category: .literature,
                audience: "All levels",
                pages: 98
            ),
            LibraryBook(
                id: "lit-4",
                title: "The Night Market Mystery",
                author: "B. Mwale",
                summary: "A page-turning mystery for teen readers: clues, characters, and a surprise ending.",
                category: .literature,
                audience: "Forms 1-3",
                pages: 186
            ),
            LibraryBook(
                id: "lit-5",
                title: "Letters Across the Sky",
                author: "T. Kaunda",
                summary: "Two friends write letters about life, exams, and hope — a gentle story of growth and resilience.",
                category: .literature,
                audience: "Forms 3-4",
                pages: 202
            )
        ]
    }
}
