import SwiftUI

struct LiveClassesView: View {
    @EnvironmentObject private var auth: AuthManager
    @ObservedObject private var store = LiveClassesStore.shared
    @State private var scheduling = false
    @State private var goNow = false
    var body: some View {
        List {
            if let error = store.error {
                Section { Text(error).foregroundColor(AppTheme.danger); Button("Retry") { Task { await store.refresh() } } }
            }
            if auth.currentUser?.canManageContent == true {
                Section {
                    Button { goNow = false; scheduling = true } label: { Label("Schedule Lesson", systemImage: "calendar.badge.plus") }
                    Button { goNow = true; scheduling = true } label: { Label("Go Live Now", systemImage: "video.badge.plus") }
                }
            }
            lessonSection("Live Now", status: .live)
            lessonSection("Upcoming Classes", status: .scheduled)
            Section("Recorded Lessons") {
                if store.recordings.isEmpty { Text("Recordings will appear here when ready.").foregroundColor(.secondary) }
                ForEach(store.recordings) { recording in
                    NavigationLink { LiveRecordingView(recording: recording) } label: {
                        VStack(alignment: .leading) { Label(recording.title, systemImage: "play.rectangle"); Text(recording.folder).font(.caption).foregroundColor(.secondary) }
                    }
                }
            }
            if auth.currentUser?.canManageContent == true {
                lessonSection("Completed Classes", status: .completed)
                lessonSection("Cancelled Classes", status: .cancelled)
            }
        }
        .navigationTitle(auth.currentUser?.isAdmin == true ? "Live Class Management" : "Live Classes")
        .toolbar(.visible, for: .navigationBar)
        .toolbar { NavigationLink { LiveNotificationsView() } label: { LiveBellLabel(count: store.unreadCount) } }
        .tint(AppTheme.brandBright)
        .refreshable { await store.refresh() }
        .task { await store.refresh() }
        .sheet(isPresented: $scheduling) { NavigationView { LiveLessonEditor(goNow: goNow) }.navigationViewStyle(.stack) }
    }
    private func lessonSection(_ title: String, status: LiveLessonStatus) -> some View {
        Section(title) {
            let rows = store.lessons.filter { $0.status == status }
            if rows.isEmpty { Text("No \(status.rawValue) classes.").foregroundColor(.secondary) }
            ForEach(rows) { lesson in NavigationLink { LiveLessonDetail(lessonID: lesson.id) } label: { LiveLessonRow(lesson: lesson) } }
        }
    }
}
struct LiveLessonRow: View {
    let lesson: LiveLesson
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(lesson.subject).font(.headline); Spacer(); Text(lesson.status == .live ? "LIVE" : lesson.grade).font(.caption.bold()).foregroundColor(lesson.status == .live ? AppTheme.danger : AppTheme.brandBright) }
            Text(lesson.topic)
            Text("\(lesson.scheduledAt.formatted(date: .abbreviated, time: .shortened)) · \(lesson.durationMinutes) min").font(.caption).foregroundColor(.secondary)
        }.padding(.vertical, 6)
    }
}
struct LiveHomeCard: View {
    @ObservedObject private var store = LiveClassesStore.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                NavigationLink { LiveClassesView() } label: { Label("Live Classes", systemImage: "video.fill").font(.headline) }
                Spacer()
                NavigationLink { LiveNotificationsView() } label: { LiveBellLabel(count: store.unreadCount) }
            }
            if let lesson = store.lessons.first(where: { $0.status == .live }) ?? store.lessons.first(where: { $0.status == .scheduled && $0.scheduledAt > Date() }) {
                NavigationLink { LiveLessonDetail(lessonID: lesson.id) } label: { LiveLessonRow(lesson: lesson) }.buttonStyle(.plain)
            } else { Text(store.error == nil ? "See upcoming classes and recorded lessons." : "Open Live Classes to retry loading lessons.").font(.subheadline).foregroundColor(.secondary) }
        }.padding(16).appCard().tint(AppTheme.brandBright)
    }
}
struct LiveBellLabel: View {
    let count: Int
    var body: some View {
        HStack(spacing: 3) { Image(systemName: "bell"); if count > 0 { Text(count > 99 ? "99+" : "\(count)").font(.caption.bold()).foregroundColor(AppTheme.danger) } }
            .accessibilityLabel("Updates, \(count) unread")
    }
}
struct LiveNotificationsView: View {
    @ObservedObject private var store = LiveClassesStore.shared
    var body: some View {
        List {
            if let error = store.error { Text(error).foregroundColor(AppTheme.danger) }
            if store.notifications.isEmpty { Text("No updates yet.").foregroundColor(.secondary) }
            ForEach(store.notifications) { item in
                NavigationLink {
                    LiveLessonDetail(lessonID: item.lessonID).task { if item.readAt == nil { await store.perform { try await store.service.markRead(item.id) } } }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { if item.readAt == nil { Circle().fill(AppTheme.brandBright).frame(width: 8, height: 8) }; Text(item.title).font(.headline) }
                        Text(item.body).font(.subheadline)
                        Text(item.createdAt, style: .relative).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }.navigationTitle("Notifications / Updates").toolbar(.visible, for: .navigationBar)
            .refreshable { await store.refresh() }
    }
}
struct LiveRecordingView: View {
    let recording: LiveRecording
    @State private var url: URL?
    @State private var error: String?
    var body: some View {
        Group {
            if let url { VideoPlayerScreen(fileName: url.absoluteString, fileExtension: "mp4", title: recording.title) }
            else if let error { VStack { Text(error); Button("Retry") { Task { await load() } } }.padding() }
            else { ProgressView("Authorizing playback…") }
        }.task { await load() }
    }
    private func load() async {
        error = nil
        do { url = try await LiveClassesService().playback(recording) } catch { self.error = error.localizedDescription }
    }
}
