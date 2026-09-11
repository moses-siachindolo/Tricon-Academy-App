import SwiftUI
import AVKit
import Combine

struct VideoPlayerScreen: View {

    let fileName: String
    let fileExtension: String
    let title: String
    var contentId: String = ""
    var topic: String = ""
    var subjectName: String = ""
    var levelRaw: String = ""
    var durationLabel: String = "Duration unavailable"

    @ObservedObject private var saved = SavedItemsManager.shared
    @State private var player: AVPlayer?
    @State private var completed = false
    @State private var hasRecordedPlayback = false
    @Environment(\.scenePhase) private var scenePhase
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
                if remoteLoadFailed {
                    remoteErrorHero
                } else if let url = videoURL {
                    VideoPlayer(player: player)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                        .onAppear {
                            if player == nil {
                                // Authenticated remote media (private buckets) may need headers;
                                // public Supabase URLs play with a plain AVPlayer.
                                player = AVPlayer(url: url)
                                player?.play()
                            }
                        }
                } else {
                    AppEmptyState(icon: "video.slash", title: "Video unavailable", message: "This lesson has no playable video. Please ask your tutor to upload it again.", accent: AppTheme.videos, soft: AppTheme.videosSoft)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .appFont(size: 20, weight: .bold)
                        .foregroundColor(AppTheme.ink)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            metaChip(icon: "book.fill", text: subjectName.isEmpty ? "Lesson" : subjectName)
                            metaChip(icon: "graduationcap.fill", text: levelRaw.isEmpty ? "All levels" : levelRaw)
                            metaChip(icon: "clock.fill", text: durationLabel)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            metaChip(icon: "book.fill", text: subjectName.isEmpty ? "Lesson" : subjectName)
                            metaChip(icon: "graduationcap.fill", text: levelRaw.isEmpty ? "All levels" : levelRaw)
                            metaChip(icon: "clock.fill", text: durationLabel)
                        }
                    }

                    if !topic.isEmpty {
                        Text(topic)
                            .appFont(size: 14, weight: .medium)
                            .foregroundColor(AppTheme.muted)
                    }
                }

                if completed {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(AppTheme.brand)
                        Text("Lesson marked complete")
                            .appFont(size: 14, weight: .semibold)
                            .foregroundColor(AppTheme.brandDeep)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(AppTheme.brandSoft)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous))
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
                        AppIconLabel(systemName: isBookmarked ? "bookmark.fill" : "bookmark",
                                     tint: isBookmarked ? AppTheme.bookmark : AppTheme.brandDeep)
                    }
                    .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Save lesson")
                }
            }
        }
        .onReceive(player?.currentItem?.publisher(for: \.status).eraseToAnyPublisher()
                   ?? Just(AVPlayerItem.Status.unknown).eraseToAnyPublisher()) { status in
            if status == .failed {
                player?.pause()
                remoteLoadFailed = true
            }
        }
        .onReceive(player?.publisher(for: \.timeControlStatus).eraseToAnyPublisher()
                   ?? Just(AVPlayer.TimeControlStatus.paused).eraseToAnyPublisher()) { status in
            guard status == .playing, !hasRecordedPlayback else { return }
            hasRecordedPlayback = true
            StatsManager.shared.recordVideoWatched()
            StatsManager.shared.recordResourceOpened(
                id: contentId, subject: subjectName, title: title,
                kind: .video, levelRaw: levelRaw
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            guard let item = notification.object as? AVPlayerItem,
                  item === player?.currentItem else { return }
            completed = true
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { player?.pause() }
        }
        .onDisappear {
            player?.pause()
        }
    }

    private var remoteErrorHero: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundColor(AppTheme.danger)
            Text("Could not load video")
                .appFont(size: 15, weight: .semibold)
                .foregroundColor(AppTheme.ink)
            Text("Check your connection and try again.")
                .appFont(size: 12.5)
                .foregroundColor(AppTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Button("Try again") {
                player = nil
                remoteLoadFailed = false
            }
            .font(.headline)
            .frame(minHeight: 44)
            .tint(AppTheme.brandBright)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(AppTheme.danger.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .appFont(size: 11.5, weight: .semibold)
        }
        .foregroundColor(AppTheme.brandDeep)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(AppTheme.brandSoft))
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
