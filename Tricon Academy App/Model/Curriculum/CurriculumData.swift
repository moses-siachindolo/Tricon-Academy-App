import Foundation

struct CurriculumData {

    // MARK: - Past Papers
    static func pastPapers(level: Level, subject: String) -> [PastPaper] {
        return [
            PastPaper(title: "\(subject) Paper 1", year: 2023, fileName: "sample_paper"),
            PastPaper(title: "\(subject) Paper 2", year: 2022, fileName: "sample_paper"),
            PastPaper(title: "\(subject) Paper 1", year: 2021, fileName: "sample_paper")
        ]
    }

    // MARK: - Materials
    static func materials(level: Level, subject: String) -> [StudyMaterial] {
        return [
            StudyMaterial(title: "Introduction Notes", topic: "Foundations", fileName: "sample_notes"),
            StudyMaterial(title: "Key Formulas & Definitions", topic: "Revision", fileName: "sample_notes")
        ]
    }

    // MARK: - Videos
    static func videos(level: Level, subject: String) -> [VideoLesson] {
        return [
            VideoLesson(title: "Topic Overview", topic: "Introduction", fileName: "sample_video", fileExtension: "mp4")
        ]
    }
}
