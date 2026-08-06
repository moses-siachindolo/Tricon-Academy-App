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
    var swiftUIColor: Color {
        switch colorName {
        case "blue": return Color(red: 0.20, green: 0.48, blue: 0.92)
        case "purple": return Color(red: 0.52, green: 0.32, blue: 0.88)
        case "orange": return Color(red: 0.95, green: 0.48, blue: 0.18)
        case "green": return Color(red: 0.10, green: 0.68, blue: 0.42)
        case "teal": return Color(red: 0.10, green: 0.62, blue: 0.55)
        case "indigo": return Color(red: 0.35, green: 0.36, blue: 0.84)
        case "brown": return Color(red: 0.55, green: 0.38, blue: 0.24)
        case "pink": return Color(red: 0.90, green: 0.36, blue: 0.55)
        default: return AppTheme.brand
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

// MARK: - App theme (shared UI tokens — adaptive light / dark)

enum AppTheme {
    static let brand = Color(red: 0.10, green: 0.68, blue: 0.42)
    static let brandDeep = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.35, green: 0.85, blue: 0.58, alpha: 1)
            : UIColor(red: 0.06, green: 0.48, blue: 0.32, alpha: 1)
    })
    static let brandSoft = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.22, blue: 0.17, alpha: 1)
            : UIColor(red: 0.88, green: 0.97, blue: 0.92, alpha: 1)
    })
    /// Main background — white in light mode, black in dark mode.
    static let canvas = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1)
            : UIColor(red: 0.965, green: 0.978, blue: 0.972, alpha: 1)
    })
    static let ink = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.95, green: 0.96, blue: 0.96, alpha: 1)
            : UIColor(red: 0.08, green: 0.12, blue: 0.11, alpha: 1)
    })
    static let muted = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.62, green: 0.66, blue: 0.64, alpha: 1)
            : UIColor(red: 0.42, green: 0.48, blue: 0.46, alpha: 1)
    })
    static let card = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.13, blue: 0.14, alpha: 1)
            : UIColor.white
    })
    static let danger = Color(red: 0.82, green: 0.22, blue: 0.22)
    static let stroke = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.black.withAlphaComponent(0.05)
    })

    static let horizontalPadding: CGFloat = 22
    static let cardRadius: CGFloat = 18
}
