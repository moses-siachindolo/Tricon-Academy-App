import SwiftUI

struct LiveLessonDetail: View {
    let lessonID: UUID
    @EnvironmentObject private var auth: AuthManager
    @ObservedObject private var store = LiveClassesStore.shared
    @State private var editing = false
    @State private var classroom = false
    @State private var attendance: [LiveAttendance] = []
    @State private var attendanceError: String?
    @State private var confirmCancel = false
    @State private var confirmEnd = false
    private var lesson: LiveLesson? { store.lessons.first { $0.id == lessonID } }
    var body: some View {
        presentedContent
            .confirmationDialog("Cancel this lesson?", isPresented: $confirmCancel) {
                Button("Cancel lesson", role: .destructive, action: cancelLesson)
            }
            .confirmationDialog("End this class for everyone?", isPresented: $confirmEnd) {
                Button("End class", role: .destructive, action: endLesson)
            }
    }

    private var presentedContent: some View {
        lessonList
            .navigationTitle("Lesson")
            .toolbar(.visible, for: .navigationBar)
            .disabled(store.busy)
            .task {
                await store.refresh()
                await loadAttendance()
            }
            .sheet(isPresented: $editing) { editorSheet }
            .fullScreenCover(isPresented: $classroom) { classroomCover }
    }

    private var lessonList: some View {
        List {
            if let lesson {
                lessonSections(lesson)
            } else {
                unavailableContent
            }
        }
    }

    @ViewBuilder
    private func lessonSections(_ lesson: LiveLesson) -> some View {
        summarySection(lesson)
        if let error = store.error {
            Text(error).foregroundColor(AppTheme.danger)
        }
        invitationSection(lesson)
        if lesson.canManage(auth.currentUser) {
            managementSection(lesson)
            attendanceSection
        }
        recordingsSection
    }

    private func summarySection(_ lesson: LiveLesson) -> some View {
        Section {
            LiveLessonRow(lesson: lesson)
            if lesson.recordingEnabled {
                Label("Recording destination: \(lesson.recordingFolder)", systemImage: "folder")
            }
        }
    }

    private func invitationSection(_ lesson: LiveLesson) -> some View {
        Section {
            if lesson.status == .live || lesson.status == .scheduled {
                Button(lesson.status == .live ? "Join Class" : "Open Classroom") {
                    classroom = true
                }
            }
            if lesson.status == .scheduled {
                Button(reminderTitle) { toggleReminder(for: lesson) }
            }
            ShareLink(item: lesson.invitationURL) {
                Label("Share invitation", systemImage: "square.and.arrow.up")
            }
            Button("Copy invitation link") {
                UIPasteboard.general.url = lesson.invitationURL
            }
        }
    }

    private var reminderTitle: String {
        store.reminders.contains(lessonID)
            ? "Remove reminders"
            : "Set 1 hour & 15 min reminders"
    }

    private func managementSection(_ lesson: LiveLesson) -> some View {
        Section("Manage lesson") {
            if lesson.status == .scheduled {
                Button("Edit lesson / recording destination") { editing = true }
                Button("Start lesson") { classroom = true }
                Button("Cancel lesson", role: .destructive) { confirmCancel = true }
            }
            if lesson.status == .live {
                Button("End lesson", role: .destructive) { confirmEnd = true }
            }
            if lesson.status == .scheduled || lesson.status == .live {
                Button("Send lesson notification", action: sendNotification)
            }
        }
    }

    private var attendanceSection: some View {
        Section("Attendance") {
            if let attendanceError {
                Text(attendanceError).foregroundColor(AppTheme.danger)
            }
            if attendance.isEmpty {
                Text("No attendance recorded yet.").foregroundColor(.secondary)
            }
            ForEach(attendance) { row in
                LiveAttendanceRow(attendance: row)
            }
            Button("Refresh attendance") {
                Task { await loadAttendance() }
            }
        }
    }

    private var lessonRecordings: [LiveRecording] {
        store.recordings.filter { $0.lessonID == lessonID }
    }

    private var recordingsSection: some View {
        Section("Recordings") {
            ForEach(lessonRecordings) { recording in
                NavigationLink(recording.title) {
                    LiveRecordingView(recording: recording)
                }
            }
        }
    }

    @ViewBuilder
    private var unavailableContent: some View {
        Text(store.error ?? "This lesson is unavailable or you do not have access.")
        Button("Retry") { Task { await store.refresh() } }
    }

    @ViewBuilder
    private var editorSheet: some View {
        if let lesson {
            NavigationView {
                LiveLessonEditor(existing: lesson)
            }
            .navigationViewStyle(.stack)
        }
    }

    @ViewBuilder
    private var classroomCover: some View {
        if let lesson {
            LiveClassroomView(lesson: lesson)
        }
    }

    private func toggleReminder(for lesson: LiveLesson) {
        Task {
            await store.setReminder(lesson, enabled: !store.reminders.contains(lessonID))
        }
    }

    private func sendNotification() {
        Task {
            await store.perform {
                try await store.service.rpc("notify_live_lesson", lessonID: lessonID)
            }
        }
    }

    private func cancelLesson() {
        Task {
            await store.perform {
                try await store.service.rpc("cancel_live_lesson", lessonID: lessonID)
            }
        }
    }

    private func endLesson() {
        Task {
            await store.perform {
                try await LiveBackend.end(lessonID)
            }
        }
    }

    private func loadAttendance() async {
        guard lesson?.canManage(auth.currentUser) == true else { return }
        do { attendance = try await store.service.attendance(lessonID); attendanceError = nil } catch { attendanceError = error.localizedDescription }
    }
}


private struct LiveAttendanceRow: View {
    let attendance: LiveAttendance

    private var departureText: String {
        guard let leftAt = attendance.leftAt else {
            return "In class / awaiting disconnect confirmation"
        }
        return "Left \(leftAt.formatted())"
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(attendance.displayName)
                .font(.caption)
                .textSelection(.enabled)
            Text("Joined \(attendance.joinedAt.formatted())")
                .font(.caption)
            Text(departureText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct LiveLessonEditor: View {
    var existing: LiveLesson? = nil
    var goNow = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthManager
    @ObservedObject private var store = LiveClassesStore.shared
    @State private var subject = ""
    @State private var topic = ""
    @State private var grade = "Form 1"
    @State private var date = Date().addingTimeInterval(3600)
    @State private var duration = 60
    @State private var recording = false
    @State private var folder = ""
    @State private var tutorID: UUID?
    @State private var validation: String?
    private var assignedUser: User? {
        if auth.currentUser?.isAdmin == true, let tutorID { return store.tutors.first { $0.id == tutorID }?.asUser }
        return auth.currentUser
    }
    private var subjects: [String] { assignedUser?.managedSubjectNames.filter { assignedUser?.canManageSubject($0) == true } ?? [] }
    var body: some View {
        Form {
            Section("Lesson") {
                if auth.currentUser?.isAdmin == true {
                    Picker("Tutor", selection: $tutorID) {
                        Text("Choose tutor").tag(Optional<UUID>.none)
                        ForEach(store.tutors.filter { $0.asUser.canManageContent }) { tutor in Text(tutor.fullName).tag(Optional(tutor.id)) }
                    }.onChange(of: tutorID) { _ in if !subjects.contains(subject) { subject = subjects.first ?? "" } }
                }
                Picker("Subject", selection: $subject) { Text("Choose subject").tag(""); ForEach(subjects, id: \.self) { Text($0).tag($0) } }
                TextField("Topic", text: $topic)
                Picker("Form / grade", selection: $grade) { ForEach(Level.activeCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) } }
                DatePicker("Starts", selection: $date, displayedComponents: [.date, .hourAndMinute])
                Stepper("\(duration) minutes", value: $duration, in: 15...240, step: 15)
            }
            Section("Recording") {
                Toggle("Enable recording", isOn: $recording)
                if recording {
                    TextField("Physics/Form 4/Kinematics/Motion Graphs", text: $folder)
                    Button("Use subject / form / topic") { folder = "\(subject)/\(grade)/\(topic)" }
                    Text("Choose the destination before starting. Recording begins only after the server confirms it.").font(.caption).foregroundColor(.secondary)
                }
            }
            if goNow { Text("Save the lesson, then open its classroom to start. Live video requires academy setup.").font(.caption) }
            if let error = validation ?? store.error { Text(error).foregroundColor(AppTheme.danger) }
            Button(existing == nil ? "Save lesson" : "Save changes") { Task { await save() } }.disabled(store.busy)
        }
        .navigationTitle(existing == nil ? (goNow ? "Go Live Now" : "Schedule Lesson") : "Edit Lesson")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .task {
            if auth.currentUser?.isAdmin == true { await store.loadTutors() }
            tutorID = existing?.tutorID ?? auth.currentUser?.id
            subject = existing?.subject ?? subjects.first ?? ""
            topic = existing?.topic ?? ""; grade = existing?.grade ?? "Form 1"
            date = existing?.scheduledAt ?? (goNow ? Date() : Date().addingTimeInterval(3600))
            duration = existing?.durationMinutes ?? 60; recording = existing?.recordingEnabled ?? false; folder = existing?.recordingFolder ?? ""
        }
    }
    private func save() async {
        guard let tutorID, assignedUser?.canManageSubject(subject) == true else { validation = "Choose a tutor and one of their approved subjects."; return }
        let title = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = folder.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 200 else { validation = "Enter a topic (up to 200 characters)."; return }
        guard goNow || date > Date() else { validation = "Choose a future start time."; return }
        guard !recording || (!destination.isEmpty && destination.count <= 300 && !destination.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0.isEmpty || $0 == ".." || $0 == "." })) else { validation = "Choose a valid recording folder without empty or relative path segments."; return }
        let lesson = LiveLesson(id: existing?.id ?? UUID(), tutorID: tutorID, subject: subject, topic: title, grade: grade, scheduledAt: goNow ? Date() : date, durationMinutes: duration, status: .scheduled, recordingEnabled: recording, recordingFolder: recording ? destination : "")
        if await store.perform({ try await store.service.save(lesson, editing: existing != nil) }) { dismiss() }
    }
}

/// The server must end the LiveKit room before reporting success to the client.
enum LiveBackend {
    static func end(_ id: UUID) async throws {
        let _ = try await SupabaseClient.shared.perform(path: "/functions/v1/live-class-control", method: "POST", body: ["action": "end", "lesson_id": id.uuidString], rawBody: nil, useUserToken: true, extraHeaders: [:])
    }
}
