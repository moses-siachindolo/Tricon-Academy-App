import SwiftUI
import PDFKit

struct PDFViewerScreen: View {

    let fileName: String
    let title: String
    /// Only "Past Papers" should count toward the "Papers solved" stat —
    /// Materials reuse this same viewer but shouldn't be counted as papers.
    var isPastPaper: Bool = true

    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: fileName, withExtension: "pdf") {
                PDFKitView(url: url)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("File not found in bundle")
                        .foregroundColor(.gray)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if isPastPaper {
                StatsManager.shared.recordPaperOpened()
            }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
