import Foundation
import Combine

struct LiveVideoParticipant: Identifiable {
    let id: String
    let name: String
    let isTutor: Bool
    var handRaised: Bool
}
struct LiveChatMessage: Identifiable {
    let id: UUID
    let sender: String
    let text: String
}

/// Implement with a LiveKit Room adapter after installing the SDK. Tokens must be
/// minted by the authenticated backend for one lesson, with short expiry.
@MainActor protocol LiveVideoService: AnyObject {
    var available: Bool { get }
    func connect(lessonID: UUID) async throws
    func disconnect() async
    func microphone(enabled: Bool) async throws
    func camera(enabled: Bool) async throws
    func screenShare(enabled: Bool) async throws
    func sendChat(_ text: String) async throws
    func raiseHand(_ raised: Bool) async throws
}

/// Deliberately fails closed: no simulated connection, attendance, or recording.
@MainActor final class UnconfiguredLiveVideoService: LiveVideoService {
    var available: Bool { false }
    private var unavailable: SupabaseError { .message("Live video is not configured yet. Your academy must connect LiveKit and deploy the live-class backend before classes can start.") }
    func connect(lessonID: UUID) async throws { throw unavailable }
    func disconnect() async {}
    func microphone(enabled: Bool) async throws { throw unavailable }
    func camera(enabled: Bool) async throws { throw unavailable }
    func screenShare(enabled: Bool) async throws { throw unavailable }
    func sendChat(_ text: String) async throws { throw unavailable }
    func raiseHand(_ raised: Bool) async throws { throw unavailable }
}

@MainActor final class LiveClassroomStore: ObservableObject {
    @Published var connected = false
    @Published var working = false
    @Published var mic = false
    @Published var camera = false
    @Published var sharing = false
    @Published var hand = false
    @Published var error: String?
    @Published var participants: [LiveVideoParticipant] = []
    @Published var messages: [LiveChatMessage] = []
    // Future adapter forwards Room participant, track, data, and disconnect events here.
    let video: any LiveVideoService
    init(video: (any LiveVideoService)? = nil) { self.video = video ?? UnconfiguredLiveVideoService() }
    func join(_ lesson: LiveLesson) async {
        guard !working, !connected else { return }
        working = true
        defer { working = false }
        do {
            try await video.connect(lessonID: lesson.id)
            // Backend LiveKit participant_joined/left webhooks own attendance.
            connected = true; error = nil
        } catch { self.error = error.localizedDescription }
    }
    func leave() async { await video.disconnect(); connected = false }
    func control(_ kind: String) async {
        guard connected, !working else { return }
        working = true
        defer { working = false }
        do {
            switch kind {
            case "mic": try await video.microphone(enabled: !mic); mic.toggle()
            case "camera": try await video.camera(enabled: !camera); camera.toggle()
            case "share": try await video.screenShare(enabled: !sharing); sharing.toggle()
            default: try await video.raiseHand(!hand); hand.toggle()
            }
        } catch { self.error = error.localizedDescription }
    }
    func send(_ text: String) async -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard connected, !text.isEmpty, text.count <= 2000 else { return false }
        do { try await video.sendChat(text); return true }
        catch { self.error = error.localizedDescription; return false }
    }
}
