import SwiftUI
import PDFKit
import UIKit

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
    @State private var generatedURL: URL?
    @State private var remoteCachedURL: URL?
    @State private var remoteLoadFailed = false

    private var resolvedURL: URL? {
        if let remoteCachedURL { return remoteCachedURL }
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
        return generatedURL
    }

    private var isRemoteFile: Bool {
        fileName.hasPrefix("http://") || fileName.hasPrefix("https://")
    }

    private var isBookmarked: Bool {
        !contentId.isEmpty && saved.isSaved(id: contentId)
    }

    var body: some View {
        Group {
            if let url = resolvedURL {
                PDFKitView(url: url)
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
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .foregroundColor(isBookmarked ? AppTheme.bookmark : AppTheme.brandDeep)
                    }
                    .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Save")
                }
            }
        }
        .onAppear {
            if isPastPaper {
                StatsManager.shared.recordPaperOpened()
            }
            if isRemoteFile {
                Task { await downloadRemotePDFIfNeeded() }
            } else if resolvedURL == nil {
                generatedURL = PDFGenerator.makeDocument(
                    title: title,
                    subject: subjectName,
                    level: levelRaw,
                    year: year,
                    topic: topic,
                    isPastPaper: isPastPaper
                )
            }
        }
    }

    private var loadingOrError: some View {
        VStack(spacing: 14) {
            if remoteLoadFailed {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .foregroundColor(AppTheme.danger)
                Text("Could not download document")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                Text("Check your connection and Supabase Storage setup.")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            } else {
                ProgressView()
                    .tint(AppTheme.brand)
                Text(isRemoteFile ? "Downloading document…" : "Preparing document…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func downloadRemotePDFIfNeeded() async {
        guard remoteCachedURL == nil, let remote = URL(string: fileName) else { return }
        do {
            let data: Data
            if SupabaseConfig.isConfigured {
                data = try await SupabaseClient.shared.downloadData(from: remote)
            } else {
                let (d, _) = try await URLSession.shared.data(from: remote)
                data = d
            }
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".pdf")
            try data.write(to: tmp)
            await MainActor.run {
                remoteCachedURL = tmp
            }
        } catch {
            await MainActor.run {
                remoteLoadFailed = true
                // Fall back to generated placeholder
                generatedURL = PDFGenerator.makeDocument(
                    title: title,
                    subject: subjectName,
                    level: levelRaw,
                    year: year,
                    topic: topic,
                    isPastPaper: isPastPaper
                )
            }
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
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor.systemGroupedBackground
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}

// MARK: - On-device PDF generation (when bundle file is missing)

enum PDFGenerator {
    static func makeDocument(
        title: String,
        subject: String,
        level: String,
        year: Int?,
        topic: String,
        isPastPaper: Bool
    ) -> URL? {
        let safeName = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tricon-\(safeName)-\(UUID().uuidString.prefix(8)).pdf")

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                let cg = context.cgContext

                // Header bar
                UIColor(red: 0.10, green: 0.68, blue: 0.42, alpha: 1).setFill()
                cg.fill(CGRect(x: 0, y: 0, width: 612, height: 90))

                let headerAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.9)
                ]
                ("TRICON ACADEMY" as NSString).draw(at: CGPoint(x: 40, y: 22), withAttributes: headerAttrs)

                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                (title as NSString).draw(in: CGRect(x: 40, y: 42, width: 532, height: 36), withAttributes: titleAttrs)

                let meta = [
                    subject.isEmpty ? "General" : subject,
                    level.isEmpty ? "All levels" : level,
                    year.map { String($0) } ?? "",
                    isPastPaper ? "Past Paper" : "Study Notes"
                ].filter { !$0.isEmpty }.joined(separator: "  ·  ")

                let bodyAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: UIColor.darkGray
                ]
                (meta as NSString).draw(at: CGPoint(x: 40, y: 110), withAttributes: bodyAttrs)

                let headingAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 15, weight: .bold),
                    .foregroundColor: UIColor.black
                ]
                let textAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.darkGray
                ]

                var y: CGFloat = 150
                if isPastPaper {
                    ("Instructions" as NSString).draw(at: CGPoint(x: 40, y: y), withAttributes: headingAttrs)
                    y += 28
                    let instructions = """
                    1. Answer all questions in the spaces provided.
                    2. Show all working clearly for calculation questions.
                    3. Use a scientific calculator where needed.
                    4. Time allowed: 2 hours.
                    5. Read each question carefully before answering.
                    """
                    (instructions as NSString).draw(in: CGRect(x: 40, y: y, width: 532, height: 140), withAttributes: textAttrs)
                    y += 150

                    ("Sample questions" as NSString).draw(at: CGPoint(x: 40, y: y), withAttributes: headingAttrs)
                    y += 28
                    let questions = """
                    1. Define the main concept introduced in this topic and give one real-world example.

                    2. Explain two key principles related to \(subject.isEmpty ? "this subject" : subject) at \(level.isEmpty ? "this level" : level).

                    3. Calculate or reason through a short problem based on the formulas in your notes. Show full working.

                    4. Discuss how this topic connects to previous work in \(subject.isEmpty ? "your course" : subject).

                    5. Write a short paragraph summarizing what you have learned and one area to revise further.
                    """
                    (questions as NSString).draw(in: CGRect(x: 40, y: y, width: 532, height: 280), withAttributes: textAttrs)
                } else {
                    let topicLine = topic.isEmpty ? "Core revision" : topic
                    ("Topic: \(topicLine)" as NSString).draw(at: CGPoint(x: 40, y: y), withAttributes: headingAttrs)
                    y += 28
                    let notes = """
                    Overview
                    These study notes cover the essential ideas for \(subject.isEmpty ? "this subject" : subject) at \(level.isEmpty ? "your level" : level). Use them for revision before tests and exams.

                    Key points
                    • Review definitions and write them in your own words.
                    • Practise with worked examples until the method feels natural.
                    • Link each idea to a past-paper style question.
                    • Mark anything unclear and revisit it with a tutor or classmate.

                    Revision checklist
                    □ I can explain the main concepts without notes.
                    □ I can complete a short practice set in timed conditions.
                    □ I know the common exam mistakes for this topic.
                    □ I have saved this note for quick access later.
                    """
                    (notes as NSString).draw(in: CGRect(x: 40, y: y, width: 532, height: 420), withAttributes: textAttrs)
                }

                let footerAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.gray
                ]
                ("Generated by Tricon Academy · For study practice" as NSString)
                    .draw(at: CGPoint(x: 40, y: 760), withAttributes: footerAttrs)
            }
            return url
        } catch {
            return nil
        }
    }
}
