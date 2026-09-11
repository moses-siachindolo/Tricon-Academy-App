import SwiftUI
import AVKit
import Combine
import CryptoKit

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
    @State private var offlineURL: URL?
    @State private var isDownloading = false
    @State private var downloadError: String?
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
                } else if videoURL != nil {
                    VideoPlayer(player: player)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
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

                if isRemoteFile {
                    VStack(alignment: .leading, spacing: 8) {
                        if offlineURL != nil {
                            Label("Available offline", systemImage: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.brand)
                                .appFont(size: 14, weight: .semibold)
                        } else {
                            Button {
                                Task { await downloadForOffline() }
                            } label: {
                                Label(isDownloading ? "Downloading…" : "Download for offline",
                                      systemImage: "arrow.down.circle")
                            }
                            .buttonStyle(AppSecondaryButtonStyle())
                            .disabled(isDownloading)
                        }
                        if let downloadError {
                            Text(downloadError)
                                .appFont(size: 13)
                                .foregroundColor(AppTheme.danger)
                        }
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
        .task(id: fileName) { await preparePlayer() }
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

    @MainActor
    private func preparePlayer() async {
        guard player == nil, let remote = videoURL else { return }
        let owner = AuthManager.shared.currentUser?.id
        let local = isRemoteFile
            ? await VideoDownloadStore.shared.cachedVideo(for: remote, userID: owner)
            : remote
        guard !Task.isCancelled, owner == AuthManager.shared.currentUser?.id else { return }
        offlineURL = local
        player = AVPlayer(url: local ?? remote)
        if scenePhase == .active { player?.play() }
    }

    @MainActor
    private func downloadForOffline() async {
        guard !isDownloading, let url = videoURL,
              let owner = AuthManager.shared.currentUser?.id else { return }
        isDownloading = true
        downloadError = nil
        defer { isDownloading = false }
        do {
            let request = SupabaseConfig.isConfigured
                ? SupabaseClient.shared.documentDownloadRequest(from: url)
                : URLRequest(url: url)
            let local = try await VideoDownloadStore.shared.download(request, userID: owner)
            guard owner == AuthManager.shared.currentUser?.id else { return }
            offlineURL = local
        } catch {
            downloadError = "Download failed. Check your connection and available storage, then try again."
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
                Task { await preparePlayer() }
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


/// Complete video files retained on device, isolated by the owning account.
actor VideoDownloadStore {
    static let shared = VideoDownloadStore()
    private let directory: URL
    private let session: URLSession
    private var downloads: [URL: Task<URL, Error>] = [:]

    init(directory: URL? = nil, session: URLSession = .shared) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OfflineVideos", isDirectory: true)
        self.session = session
    }

    private func destination(for url: URL, userID: UUID) -> URL {
        let identity = url.absoluteString + "\naccount:" + userID.uuidString.lowercased()
        let key = SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
        let ext = ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased()) ? url.pathExtension.lowercased() : "mp4"
        return directory.appendingPathComponent(key + "." + ext)
    }

    func cachedVideo(for url: URL, userID: UUID?) async -> URL? {
        guard let userID else { return nil }
        let file = destination(for: url, userID: userID)
        guard FileManager.default.fileExists(atPath: file.path),
              (try? await AVURLAsset(url: file).load(.isPlayable)) == true else { return nil }
        return file
    }

    func download(_ request: URLRequest, userID: UUID) async throws -> URL {
        guard let url = request.url else { throw URLError(.badURL) }
        if let local = await cachedVideo(for: url, userID: userID) { return local }
        let file = destination(for: url, userID: userID)
        if let existing = downloads[file] { return try await existing.value }
        let task = Task { try await self.transfer(request, to: file) }
        downloads[file] = task
        defer { downloads[file] = nil }
        return try await task.value
    }

    private func transfer(_ request: URLRequest, to file: URL) async throws -> URL {
        let (temporary, response) = try await session.download(for: request)
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        // Validate a local media file; streaming playlists are not complete offline videos.
        let staged = temporary.appendingPathExtension(file.pathExtension)
        try FileManager.default.moveItem(at: temporary, to: staged)
        defer { try? FileManager.default.removeItem(at: staged) }
        guard try await AVURLAsset(url: staged).load(.isPlayable),
              let size = try FileManager.default.attributesOfItem(atPath: staged.path)[.size] as? NSNumber,
              size.intValue > 0,
              !["m3u8", "m3u"].contains(request.url?.pathExtension.lowercased() ?? "") else {
            throw URLError(.cannotDecodeContentData)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var location = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try location.setResourceValues(values)
        if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
        try FileManager.default.moveItem(at: staged, to: file)
        return file
    }
}
