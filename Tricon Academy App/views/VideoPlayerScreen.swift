import SwiftUI
import AVKit

struct VideoPlayerScreen: View {

    let fileName: String
    let fileExtension: String
    let title: String
    var contentId: String = ""
    var topic: String = ""
    var subjectName: String = ""
    var levelRaw: String = ""
    var durationLabel: String = "10 min"

    @ObservedObject private var saved = SavedItemsManager.shared
    @State private var player: AVPlayer?
    @State private var lessonProgress: Double = 0
    @State private var completed = false
    @State private var isPlayingLesson = false
    @State private var remoteLoadFailed = false

    private var isRemoteFile: Bool {
        fileName.hasPrefix("http://") || fileName.hasPrefix("https://")
    }

    private var videoURL: URL? {
        // Cloud / remote uploads (Supabase public or signed-style HTTPS paths)
        if isRemoteFile, let remote = URL(string: fileName) {
            return remote
        }
        // Absolute path from local uploads
        if fileName.hasPrefix("/") {
            let url = URL(fileURLWithPath: fileName)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        if let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) {
            return url
        }
        let name = (fileName as NSString).deletingPathExtension
        let ext = fileExtension.isEmpty ? (fileName as NSString).pathExtension : fileExtension
        return Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "mp4" : ext)
    }

    private var isBookmarked: Bool {
        !contentId.isEmpty && saved.isSaved(id: contentId)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                if let url = videoURL {
                    VideoPlayer(player: player ?? AVPlayer(url: url))
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .onAppear {
                            if player == nil {
                                // Authenticated remote media (private buckets) may need headers;
                                // public Supabase URLs play with a plain AVPlayer.
                                player = AVPlayer(url: url)
                                player?.play()
                            }
                        }
                } else if remoteLoadFailed {
                    remoteErrorHero
                } else {
                    lessonHero
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.ink)

                    HStack(spacing: 8) {
                        metaChip(icon: "book.fill", text: subjectName.isEmpty ? "Lesson" : subjectName)
                        metaChip(icon: "graduationcap.fill", text: levelRaw.isEmpty ? "All levels" : levelRaw)
                        metaChip(icon: "clock.fill", text: durationLabel)
                    }

                    if !topic.isEmpty {
                        Text(topic)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.muted)
                    }
                }

                // Lesson outline (always useful, even with real video)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Lesson outline")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.ink)

                    outlineRow(number: "1", title: "Introduction", detail: "Context and learning goals")
                    outlineRow(number: "2", title: "Core concepts", detail: "Main ideas explained clearly")
                    outlineRow(number: "3", title: "Worked examples", detail: "Step-by-step practice")
                    outlineRow(number: "4", title: "Exam tips", detail: "Common mistakes and scoring")
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.brand.opacity(0.10), lineWidth: 1)
                )

                if videoURL == nil {
                    interactiveLessonCard
                }

                if completed {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(AppTheme.brand)
                        Text("Lesson marked complete")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.brandDeep)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(AppTheme.brandSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("Lesson")
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
                }
            }
        }
        .onAppear {
            StatsManager.shared.recordVideoWatched()
        }
        .onDisappear {
            player?.pause()
        }
    }

    private var lessonHero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.52, green: 0.32, blue: 0.88),
                            Color(red: 0.28, green: 0.18, blue: 0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)
                .shadow(color: Color(red: 0.52, green: 0.32, blue: 0.88).opacity(0.28), radius: 16, x: 0, y: 8)

            VStack(spacing: 12) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
                Text("Interactive lesson")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text("Video file not available — complete the guided lesson below.")
                    .font(.system(size: 12.5))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }

    private var remoteErrorHero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.danger.opacity(0.12))
                .frame(height: 160)
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AppTheme.danger)
                Text("Could not load video")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                Text("Check your connection or Storage bucket permissions.")
                    .font(.system(size: 12.5))
                    .foregroundColor(AppTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
    }

    private var interactiveLessonCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Guided practice")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.ink)

            ProgressView(value: lessonProgress)
                .tint(AppTheme.brand)

            Text(isPlayingLesson ? "Working through the lesson…" : "Start the guided session to build your streak.")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.muted)

            Button {
                runGuidedLesson()
            } label: {
                HStack {
                    Image(systemName: completed ? "arrow.clockwise" : "play.fill")
                    Text(completed ? "Replay lesson" : (isPlayingLesson ? "In progress…" : "Start lesson"))
                        .fontWeight(.semibold)
                }
                .font(.system(size: 15))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [AppTheme.brand, AppTheme.brandDeep],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(isPlayingLesson)
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.brand.opacity(0.10), lineWidth: 1)
        )
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 11.5, weight: .semibold))
        }
        .foregroundColor(AppTheme.brandDeep)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(AppTheme.brandSoft))
    }

    private func outlineRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(AppTheme.brand))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                Text(detail)
                    .font(.system(size: 12.5))
                    .foregroundColor(AppTheme.muted)
            }
            Spacer(minLength: 0)
        }
    }

    private func runGuidedLesson() {
        isPlayingLesson = true
        completed = false
        lessonProgress = 0
        let steps = 8
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.35) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    lessonProgress = Double(i) / Double(steps)
                }
                if i == steps {
                    isPlayingLesson = false
                    completed = true
                }
            }
        }
    }

    private func toggleBookmark() {
        guard !contentId.isEmpty else { return }
        let level = Level(rawValue: levelRaw) ?? .form1
        saved.toggleVideo(
            VideoLesson(
                id: contentId,
                title: title,
                topic: topic.isEmpty ? "Lesson" : topic,
                fileName: fileName,
                fileExtension: fileExtension,
                level: level,
                subjectName: subjectName,
                durationLabel: durationLabel
            )
        )
    }
}
