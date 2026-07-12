import SwiftUI

// MARK: - Level
enum Level: String, CaseIterable, Identifiable, Codable {
    case form1 = "Form 1"
    case form2 = "Form 2"
    case form3 = "Form 3"
    case aLevel = "A-Level"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .form1: return "1.circle.fill"
        case .form2: return "2.circle.fill"
        case .form3: return "3.circle.fill"
        case .aLevel: return "graduationcap.fill"
        }
    }
}

// MARK: - Subject
struct Subject: Identifiable, Codable {
    var id: String { name }
    let name: String
    let icon: String
    let colorName: String   // resolved to a Color below
}

extension Subject {
    var swiftUIColor: Color {
        switch colorName {
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "green": return .green
        case "teal": return .teal
        case "indigo": return .indigo
        case "brown": return .brown
        case "pink": return .pink
        default: return .green
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

// MARK: - Content types

struct PastPaper: Identifiable, Codable {
    var id = UUID()
    let title: String
    let year: Int
    let fileName: String   // PDF file name in bundle, without extension
}

struct StudyMaterial: Identifiable, Codable {
    var id = UUID()
    let title: String
    let topic: String
    let fileName: String   // PDF or notes file name in bundle
}

struct VideoLesson: Identifiable, Codable {
    var id = UUID()
    let title: String
    let topic: String
    let fileName: String   // video file name in bundle, without extension
    let fileExtension: String // e.g. "mp4"
}
