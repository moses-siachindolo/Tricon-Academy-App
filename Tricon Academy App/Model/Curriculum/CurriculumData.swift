import Foundation

struct CurriculumData {

    // MARK: - Past Papers

    static func pastPapers(level: Level, subject: String) -> [PastPaper] {
        let years = paperYears(for: level)
        // Index-safe: a short (or empty) year list falls back instead of trapping.
        let fallbackYear = years.first ?? Calendar.current.component(.year, from: Date())
        func year(_ index: Int) -> Int {
            guard years.indices.contains(index) else { return fallbackYear }
            return years[index]
        }
        let papers: [(String, Int)] = [
            ("\(subject) Paper 1", year(0)),
            ("\(subject) Paper 2", year(1)),
            ("\(subject) Mid-Year Exam", year(2)),
            ("\(subject) End-of-Year Exam", year(0))
        ]

        return papers.enumerated().map { index, item in
            PastPaper(
                id: "paper-\(level.rawValue)-\(subject)-\(item.0)-\(item.1)-\(index)",
                title: item.0,
                year: item.1,
                fileName: "sample_paper",
                level: level,
                subjectName: subject
            )
        }
    }

    // MARK: - Materials

    static func materials(level: Level, subject: String) -> [StudyMaterial] {
        let items: [(String, String)] = [
            ("\(subject) Introduction Notes", "Foundations · \(level.rawValue)"),
            ("Key Concepts Summary", "Core topics"),
            ("Formulas & Definitions", "Quick revision"),
            ("Practice Worked Examples", "Exam prep")
        ]

        return items.enumerated().map { index, item in
            StudyMaterial(
                id: "material-\(level.rawValue)-\(subject)-\(index)",
                title: item.0,
                topic: item.1,
                fileName: "sample_notes",
                level: level,
                subjectName: subject
            )
        }
    }

    // MARK: - Videos

    static func videos(level: Level, subject: String) -> [VideoLesson] {
        let items: [(String, String, String)] = [
            ("\(subject) Topic Overview", "Introduction", "12 min"),
            ("Core Concepts Explained", "Main ideas", "18 min"),
            ("Exam Skills Walkthrough", "Exam prep", "15 min")
        ]

        return items.enumerated().map { index, item in
            VideoLesson(
                id: "video-\(level.rawValue)-\(subject)-\(index)",
                title: item.0,
                topic: item.1,
                fileName: "sample_video",
                fileExtension: "mp4",
                level: level,
                subjectName: subject,
                durationLabel: item.2
            )
        }
    }

    // MARK: - Helpers

    private static func paperYears(for level: Level) -> [Int] {
        switch level {
        case .form1: return [2024, 2023, 2022]
        case .form2: return [2024, 2023, 2022]
        case .form3: return [2024, 2023, 2021]
        case .form4: return [2024, 2023, 2022]
        case .aLevel: return [2024, 2023, 2022]
        }
    }
}
