import SwiftUI
import UIKit

// MARK: - Level

enum Level: String, CaseIterable, Identifiable, Codable {
    case form1 = "Form 1"
    case form2 = "Form 2"
    case form3 = "Form 3"
    case form4 = "Form 4"
    /// Kept for stored data / decoding; hidden from UI for now.
    case aLevel = "A-Level"

    var id: String { rawValue }

    /// Forms currently shown in pickers (A-Level omitted until ready).
    static var activeCases: [Level] {
        [.form1, .form2, .form3, .form4]
    }

    var icon: String {
        switch self {
        case .form1: return "1.circle.fill"
        case .form2: return "2.circle.fill"
        case .form3: return "3.circle.fill"
        case .form4: return "4.circle.fill"
        case .aLevel: return "graduationcap.fill"
        }
    }

    var shortLabel: String {
        switch self {
        case .form1: return "F1"
        case .form2: return "F2"
        case .form3: return "F3"
        case .form4: return "F4"
        case .aLevel: return "AL"
        }
    }

    /// Distinct accent for form folders.
    var accent: Color {
        switch self {
        case .form1: return Color(red: 0.10, green: 0.68, blue: 0.42)
        case .form2: return Color(red: 0.20, green: 0.48, blue: 0.92)
        case .form3: return Color(red: 0.52, green: 0.32, blue: 0.88)
        case .form4: return Color(red: 0.95, green: 0.48, blue: 0.18)
        case .aLevel: return Color(red: 0.10, green: 0.62, blue: 0.55)
        }
    }

    var accentDeep: Color {
        switch self {
        case .form1: return Color(red: 0.06, green: 0.48, blue: 0.32)
        case .form2: return Color(red: 0.12, green: 0.32, blue: 0.72)
        case .form3: return Color(red: 0.36, green: 0.20, blue: 0.72)
        case .form4: return Color(red: 0.78, green: 0.34, blue: 0.10)
        case .aLevel: return Color(red: 0.06, green: 0.44, blue: 0.40)
        }
    }

    var defaultSubtitle: String {
        "\(allSubjects.count) subjects"
    }
}

// MARK: - Subject

struct Subject: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let icon: String
    let colorName: String
}

extension Subject {
    /// Adaptive subject accent — deeper in light mode, brighter in dark for icon contrast.
    var swiftUIColor: Color {
        switch colorName {
        case "blue":
            return Color(UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 0.45, green: 0.68, blue: 1.0, alpha: 1)
                    : UIColor(red: 0.12, green: 0.38, blue: 0.82, alpha: 1)
            })
        case "purple":
            return Color(UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 0.72, green: 0.58, blue: 1.0, alpha: 1)
                    : UIColor(red: 0.42, green: 0.24, blue: 0.78, alpha: 1)
            })
        case "orange":
            return Color(UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 1.0, green: 0.68, blue: 0.32, alpha: 1)
                    : UIColor(red: 0.88, green: 0.40, blue: 0.08, alpha: 1)
            })
        case "green":
            return Color(UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 0.38, green: 0.88, blue: 0.62, alpha: 1)
                    : UIColor(red: 0.07, green: 0.55, blue: 0.34, alpha: 1)
            })
        case "teal":
            return Color(UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 0.35, green: 0.88, blue: 0.78, alpha: 1)
                    : UIColor(red: 0.05, green: 0.50, blue: 0.46, alpha: 1)
            })
        case "indigo":
            return Color(UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 0.58, green: 0.62, blue: 1.0, alpha: 1)
                    : UIColor(red: 0.30, green: 0.30, blue: 0.72, alpha: 1)
            })
        case "brown":
            return Color(UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 0.90, green: 0.72, blue: 0.52, alpha: 1)
                    : UIColor(red: 0.48, green: 0.32, blue: 0.18, alpha: 1)
            })
        case "pink":
            return Color(UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 1.0, green: 0.58, blue: 0.72, alpha: 1)
                    : UIColor(red: 0.80, green: 0.26, blue: 0.45, alpha: 1)
            })
        default:
            return AppTheme.brandBright
        }
    }
}

// Core subjects shown on the main subject grid
let allSubjects: [Subject] = [
    Subject(name: "Physics", icon: "atom", colorName: "blue"),
    Subject(name: "Mathematics", icon: "function", colorName: "purple"),
    Subject(name: "Chemistry", icon: "testtube.2", colorName: "orange"),
    Subject(name: "Biology", icon: "leaf.fill", colorName: "green"),
    Subject(name: "English", icon: "book.fill", colorName: "teal"),
    Subject(name: "Optionals", icon: "square.grid.2x2.fill", colorName: "pink")
]

// Subjects nested inside "Optionals"
let optionalSubjects: [Subject] = [
    Subject(name: "Civic Education", icon: "building.columns.fill", colorName: "indigo"),
    Subject(name: "Accounts", icon: "banknote.fill", colorName: "green"),
    Subject(name: "Religious Education", icon: "book.closed.fill", colorName: "brown"),
    Subject(name: "Computer Science", icon: "chevron.left.forwardslash.chevron.right", colorName: "blue")
]

// MARK: - Content types (stable IDs for bookmarks)

struct PastPaper: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let year: Int
    let fileName: String
    let level: Level
    let subjectName: String
}

struct StudyMaterial: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let topic: String
    let fileName: String
    let level: Level
    let subjectName: String
}

struct VideoLesson: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let topic: String
    let fileName: String
    let fileExtension: String
    let level: Level
    let subjectName: String
    /// Optional duration label for the UI (e.g. "12 min")
    var durationLabel: String = "10 min"
}

// MARK: - App theme (shared UI tokens — WCAG-friendly light / dark)

/// Semantic colors that stay readable at high screen brightness and in pure black mode.
/// Primary text (`ink`) and secondary text (`muted`) are tuned for ≥4.5:1 contrast on `canvas` / `card`.
enum AppTheme {

    // MARK: Brand

    /// Core brand green — safe on white buttons and light cards.
    static let brand = Color(red: 0.07, green: 0.58, blue: 0.36)
    /// Brighter brand for fills in dark mode (icons, selected chips).
    static let brandBright = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.38, green: 0.88, blue: 0.62, alpha: 1)
            : UIColor(red: 0.07, green: 0.58, blue: 0.36, alpha: 1)
    })
    /// High-contrast brand text/icons on soft brand surfaces.
    static let brandDeep = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.55, green: 0.95, blue: 0.72, alpha: 1)
            : UIColor(red: 0.04, green: 0.38, blue: 0.24, alpha: 1)
    })
    static let brandSoft = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.20, blue: 0.15, alpha: 1)
            : UIColor(red: 0.86, green: 0.96, blue: 0.90, alpha: 1)
    })
    /// Text / icons on solid brand fills (always white for max contrast).
    static let onBrand = Color.white

    // MARK: Surfaces

    /// Main app background.
    static let canvas = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.04, green: 0.045, blue: 0.05, alpha: 1)
            : UIColor(red: 0.955, green: 0.962, blue: 0.968, alpha: 1)
    })
    /// Elevated cards / sheets.
    static let card = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1)
            : UIColor.white
    })
    /// Nested fields inside cards.
    static let field = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.17, blue: 0.18, alpha: 1)
            : UIColor(red: 0.945, green: 0.950, blue: 0.958, alpha: 1)
    })
    /// Subtle fill for chips / secondary controls.
    static let fill = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.black.withAlphaComponent(0.05)
    })

    // MARK: Text (high contrast)

    /// Primary body / titles — near black / near white.
    static let ink = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.98, green: 0.985, blue: 0.99, alpha: 1)
            : UIColor(red: 0.04, green: 0.06, blue: 0.07, alpha: 1)
    })
    /// Secondary labels — still readable at full brightness (darker than typical “gray”).
    static let muted = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.72, green: 0.75, blue: 0.74, alpha: 1)
            : UIColor(red: 0.30, green: 0.34, blue: 0.36, alpha: 1)
    })
    /// Tertiary / chevrons — never pure light-gray on white.
    static let subtle = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.55, green: 0.58, blue: 0.58, alpha: 1)
            : UIColor(red: 0.42, green: 0.46, blue: 0.48, alpha: 1)
    })

    // MARK: Borders & feedback

    static let stroke = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.14)
            : UIColor.black.withAlphaComponent(0.10)
    })
    static let strokeStrong = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.22)
            : UIColor.black.withAlphaComponent(0.14)
    })
    static let danger = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.42, blue: 0.40, alpha: 1)
            : UIColor(red: 0.78, green: 0.16, blue: 0.16, alpha: 1)
    })
    static let dangerSoft = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.28, green: 0.10, blue: 0.10, alpha: 1)
            : UIColor(red: 0.98, green: 0.92, blue: 0.92, alpha: 1)
    })
    static let success = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.40, green: 0.90, blue: 0.55, alpha: 1)
            : UIColor(red: 0.08, green: 0.55, blue: 0.32, alpha: 1)
    })

    // MARK: Content-type accents (Papers / Notes / Videos)

    static let papers = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.45, green: 0.68, blue: 1.0, alpha: 1)
            : UIColor(red: 0.12, green: 0.38, blue: 0.82, alpha: 1)
    })
    static let papersSoft = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.18, blue: 0.32, alpha: 1)
            : UIColor(red: 0.90, green: 0.93, blue: 0.99, alpha: 1)
    })
    static let notes = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.35, green: 0.88, blue: 0.78, alpha: 1)
            : UIColor(red: 0.05, green: 0.50, blue: 0.46, alpha: 1)
    })
    static let notesSoft = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.20, blue: 0.18, alpha: 1)
            : UIColor(red: 0.88, green: 0.96, blue: 0.94, alpha: 1)
    })
    static let videos = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.72, green: 0.58, blue: 1.0, alpha: 1)
            : UIColor(red: 0.42, green: 0.24, blue: 0.78, alpha: 1)
    })
    static let videosSoft = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.18, green: 0.12, blue: 0.30, alpha: 1)
            : UIColor(red: 0.94, green: 0.90, blue: 0.99, alpha: 1)
    })
    static let bookmark = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.68, blue: 0.32, alpha: 1)
            : UIColor(red: 0.88, green: 0.40, blue: 0.08, alpha: 1)
    })
    static let folder = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.82, blue: 0.35, alpha: 1)
            : UIColor(red: 0.78, green: 0.52, blue: 0.06, alpha: 1)
    })
    static let folderSoft = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.24, green: 0.18, blue: 0.06, alpha: 1)
            : UIColor(red: 0.99, green: 0.94, blue: 0.84, alpha: 1)
    })

    // MARK: Layout

    static let horizontalPadding: CGFloat = 20
    static let cardRadius: CGFloat = 18
    static let controlRadius: CGFloat = 14

    // MARK: Shadows (adaptive — visible in light, subtle in dark)

    static let shadow = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.45)
            : UIColor.black.withAlphaComponent(0.08)
    })

    static func color(for section: ContentSection) -> Color {
        switch section {
        case .papers: return papers
        case .notes: return notes
        case .videos: return videos
        }
    }

    static func softColor(for section: ContentSection) -> Color {
        switch section {
        case .papers: return papersSoft
        case .notes: return notesSoft
        case .videos: return videosSoft
        }
    }

    static func icon(for section: ContentSection) -> String {
        switch section {
        case .papers: return "doc.text.fill"
        case .notes: return "note.text"
        case .videos: return "play.rectangle.fill"
        }
    }
}
