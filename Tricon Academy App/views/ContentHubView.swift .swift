import SwiftUI

struct ContentHubView: View {

    let level: Level
    let subject: Subject

    @State private var selectedTab: Int

    init(level: Level, subject: Subject, initialTab: Int = 0) {
        self.level = level
        self.subject = subject
        _selectedTab = State(initialValue: initialTab)
    }

    private var papers: [PastPaper] {
        CurriculumData.pastPapers(level: level, subject: subject.name)
    }

    private var materials: [StudyMaterial] {
        CurriculumData.materials(level: level, subject: subject.name)
    }

    private var videos: [VideoLesson] {
        CurriculumData.videos(level: level, subject: subject.name)
    }

    var body: some View {
        VStack(spacing: 0) {

            Picker("Content type", selection: $selectedTab) {
                Text("Past Papers").tag(0)
                Text("Materials").tag(1)
                Text("Videos").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                VStack(spacing: 12) {
                    switch selectedTab {
                    case 0:
                        if papers.isEmpty {
                            emptyState(
                                icon: "doc.text.magnifyingglass",
                                title: "No past papers yet",
                                message: "Past papers for \(subject.name) at \(level.rawValue) will show up here."
                            )
                        } else {
                            ForEach(papers) { paper in
                                NavigationLink(destination: PDFViewerScreen(fileName: paper.fileName, title: paper.title, isPastPaper: true)) {
                                    contentRow(icon: "doc.text.fill", title: paper.title, subtitle: "\(paper.year)")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    case 1:
                        if materials.isEmpty {
                            emptyState(
                                icon: "note.text",
                                title: "No materials yet",
                                message: "Study notes for \(subject.name) will appear here when available."
                            )
                        } else {
                            ForEach(materials) { material in
                                NavigationLink(destination: PDFViewerScreen(fileName: material.fileName, title: material.title, isPastPaper: false)) {
                                    contentRow(icon: "note.text", title: material.title, subtitle: material.topic)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    default:
                        if videos.isEmpty {
                            emptyState(
                                icon: "play.rectangle",
                                title: "No videos yet",
                                message: "Video lessons for \(subject.name) will show up here."
                            )
                        } else {
                            ForEach(videos) { video in
                                NavigationLink(destination: VideoPlayerScreen(fileName: video.fileName, fileExtension: video.fileExtension, title: video.title)) {
                                    contentRow(icon: "play.circle.fill", title: video.title, subtitle: video.topic)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(subject.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 70, height: 70)
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(.green)
            }
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func contentRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.green)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(14)
        .contentShape(Rectangle())
    }
}

struct ContentHubView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ContentHubView(level: .form1, subject: allSubjects[0])
        }
    }
}
