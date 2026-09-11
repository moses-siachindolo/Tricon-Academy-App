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

    // MARK: Brand (one academic forest teal — login through classroom)

    /// Core brand — deep forest teal. Reads as growth / academy, not generic iOS blue.
    static let brand = Color(red: 0.05, green: 0.42, blue: 0.31)
    /// Solid fill endpoint: stays dark enough for white labels in both appearances.
    static let brandFillDeep = Color(red: 0.03, green: 0.28, blue: 0.21)
    /// Brighter brand for fills in dark mode (icons, selected chips).
    static let brandBright = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.38, green: 0.86, blue: 0.64, alpha: 1)
            : UIColor(red: 0.05, green: 0.42, blue: 0.31, alpha: 1)
    })
    /// High-contrast brand text/icons on soft brand surfaces.
    static let brandDeep = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.52, green: 0.90, blue: 0.72, alpha: 1)
            : UIColor(red: 0.03, green: 0.28, blue: 0.21, alpha: 1)
    })
    static let brandSoft = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.18, blue: 0.14, alpha: 1)
            : UIColor(red: 0.88, green: 0.95, blue: 0.91, alpha: 1)
    })
    /// Classroom icon/heading green — stronger than brand so it holds up in bright light.
    static let iconGreen = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.48, green: 0.86, blue: 0.68, alpha: 1)
            : UIColor(red: 0.02, green: 0.22, blue: 0.16, alpha: 1)
    })
    /// Darker secondary copy for captions and metadata.
    static let secondaryInk = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.82, green: 0.85, blue: 0.84, alpha: 1)
            : UIColor(red: 0.20, green: 0.24, blue: 0.25, alpha: 1)
    })
    /// Icon well on white cards.
    static let iconWell = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.20, blue: 0.16, alpha: 1)
            : UIColor(red: 0.80, green: 0.90, blue: 0.85, alpha: 1)
    })
    /// Card outline that stays visible at high brightness.
    static let cardLine = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.22)
            : UIColor(red: 0.06, green: 0.22, blue: 0.17, alpha: 0.12)
    })
    /// Text / icons on solid brand fills (always white for max contrast).
    static let onBrand = Color.white

    /// Legacy aliases — same as brand so entry and post-login stay unified.
    static let entryGreen = brand
    static let entryGreenDeep = Color(red: 0.03, green: 0.28, blue: 0.21)

    // MARK: Surfaces (semantic — follow Light/Dark from AppSettings)

    /// Main app background.
    static let canvas = Color(UIColor.systemGroupedBackground)
    /// Elevated cards / sheets.
    static let card = Color(UIColor.secondarySystemGroupedBackground)
    /// Nested fields inside cards.
    static let field = Color(UIColor.tertiarySystemBackground)
    /// Subtle fill for chips / secondary controls.
    static let fill = Color(UIColor.tertiarySystemFill)

    // MARK: Text (semantic)

    /// Primary body / titles.
    static let ink = Color.primary
    /// Secondary labels.
    static let muted = Color.secondary
    /// Tertiary / chevrons.
    static let subtle = Color(UIColor.tertiaryLabel)

    // MARK: Borders & feedback

    static let stroke = Color(UIColor.separator)
    static let strokeStrong = Color(UIColor.opaqueSeparator)
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
    static let warning = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.72, blue: 0.40, alpha: 1)
            : UIColor(red: 0.58, green: 0.31, blue: 0.05, alpha: 1)
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

    // MARK: Auth aliases (same as brand blue — used by verification screens)

    static let authBlue = brand
    static let authBlueDeep = brandDeep
    static let authBlueSoft = brandSoft

    /// Soft top wash used on subject grids / post-login screens.
    static var authBlueWash: some View {
        ZStack {
            canvas.ignoresSafeArea()
            LinearGradient(
                colors: [brandSoft.opacity(0.85), canvas, canvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    /// Classroom wash used on Home, Browse, subject hubs, and Library.
    static var classroomWash: some View {
        ZStack {
            canvas.ignoresSafeArea()
            LinearGradient(
                colors: [brandSoft.opacity(0.38), canvas, canvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: Layout

    static let iconRadius: CGFloat = 12
    static let heroRadius: CGFloat = 24
    static let minimumTapTarget: CGFloat = 44
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
