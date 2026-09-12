import SwiftUI

struct LiveClassroomView: View {
    let lesson: LiveLesson
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var room = LiveClassroomStore()
    @ObservedObject private var classes = LiveClassesStore.shared
    @State private var chat = ""
    @State private var endConfirmation = false
    private var currentLesson: LiveLesson { classes.lessons.first { $0.id == lesson.id } ?? lesson }
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20).fill(AppTheme.card)
                        VStack(spacing: 12) {
                            Image(systemName: "video.slash.fill").font(.system(size: 48)).foregroundColor(AppTheme.muted)
                            Text(room.connected ? "Waiting for tutor video" : "Classroom preview").font(.headline)
                            Text(lesson.topic).foregroundColor(.secondary)
                        }.padding()
                    }.frame(minHeight: 250)
                    HStack {
                        Label("\(room.participants.count) participants", systemImage: "person.2.fill")
                        Spacer()
                        if currentLesson.recordingActive { Label("Recording", systemImage: "record.circle.fill").foregroundColor(AppTheme.danger) }
                    }.font(.caption)
                    if let error = room.error { Text(error).foregroundColor(AppTheme.danger) }
                    if let error = classes.error { Text(error).foregroundColor(AppTheme.danger) }
                    if !room.video.available {
                        Text("Live video is awaiting academy setup. Microphone, camera, screen sharing and chat become available when LiveKit is connected.").font(.subheadline).foregroundColor(.secondary)
                    }
                    if !room.connected {
                        Button("Join Class") { Task { await room.join(currentLesson) } }.buttonStyle(.borderedProminent).disabled(room.working || currentLesson.status != .live)
                        if currentLesson.status == .scheduled { Text("The tutor has not started this class.").font(.caption) }
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 95))], spacing: 12) {
                        control(room.mic ? "Mute" : "Microphone", icon: room.mic ? "mic.fill" : "mic.slash", kind: "mic")
                        control("Camera", icon: room.camera ? "video.fill" : "video.slash", kind: "camera")
                        control("Screen share", icon: "rectangle.on.rectangle", kind: "share")
                        control(room.hand ? "Lower hand" : "Raise hand", icon: "hand.raised", kind: "hand")
                    }.disabled(!room.connected || room.working)
                    if currentLesson.canManage(auth.currentUser) {
                        if currentLesson.status == .scheduled {
                            Button("Start lesson") { room.error = "LiveKit and the authenticated start/recording backend must be configured before starting a lesson." }
                            if currentLesson.recordingEnabled { Text("Recording folder: \(currentLesson.recordingFolder)").font(.caption) }
                        }
                        if currentLesson.status == .live { Button("End class for everyone", role: .destructive) { endConfirmation = true }.disabled(classes.busy) }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Participants").font(.headline)
                        if room.participants.isEmpty { Text("No connected participants").foregroundColor(.secondary) }
                        ForEach(room.participants) { participant in HStack { Text(participant.name); if participant.isTutor { Text("Tutor").font(.caption) }; if participant.handRaised { Image(systemName: "hand.raised.fill") } } }
                        Divider()
                        Text("Class chat").font(.headline)
                        ForEach(room.messages) { message in Text("\(message.sender): \(message.text)") }
                        HStack { TextField("Message", text: $chat); Button("Send") { Task { if await room.send(chat) { chat = "" } } } }.disabled(!room.connected)
                    }.padding().appCard()
                }.padding(20)
            }.background(AppTheme.canvas).navigationTitle(lesson.subject).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Leave", role: .destructive) { Task { await room.leave(); dismiss() } } } }
        }.navigationViewStyle(.stack).tint(AppTheme.brandBright)
            .onDisappear { Task { await room.leave() } }
            .confirmationDialog("End this class for everyone?", isPresented: $endConfirmation) {
                Button("End class", role: .destructive) { Task { if await classes.perform({ try await LiveBackend.end(lesson.id) }) { await room.leave(); dismiss() } } }
            }
    }
    private func control(_ title: String, icon: String, kind: String) -> some View {
        Button { Task { await room.control(kind) } } label: { VStack { Image(systemName: icon).font(.title2); Text(title).font(.caption) }.frame(maxWidth: .infinity, minHeight: 65) }.buttonStyle(.bordered)
    }
}
