"""Foundation-only production Live Classes checks; no iOS SDK or network needed."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = r'''
import Foundation
import Combine
struct User {
    let id: UUID
    var isAdmin = false
    var subjects: [String] = []
    func canManageSubject(_ name: String) -> Bool { isAdmin || subjects.contains(name) }
}
struct RemoteProfile: Decodable {}
enum SupabaseError: Error, LocalizedError {
    case noSession, invalidURL, message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return "Unavailable" }
}
enum SupabaseConfig { static let projectURL = "https://academy.example.invalid" }
final class SupabaseClient {
    static let shared = SupabaseClient()
    var userId: UUID? = UUID()
    var payload: [String: Any] = [:]
    var result = Data("[{\"id\":\"ok\"}]".utf8)
    func select<T: Decodable>(table: String, query: String = "") async throws -> T { try JSONDecoder().decode(T.self, from: result) }
    func perform<B: Encodable>(path: String, method: String, body: B?, rawBody: Data?, useUserToken: Bool, extraHeaders: [String: String]) async throws -> Data {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        if let body { payload = try JSONSerialization.jsonObject(with: encoder.encode(body)) as? [String: Any] ?? [:] }
        return result
    }
    func insert<T: Encodable,R: Decodable>(table: String,row: T) async throws -> R { try JSONDecoder().decode(R.self,from: result) }
    func update<T: Encodable>(table: String,query: String,values: T) async throws {}
    func delete(table: String,query: String) async throws {}
}
'''
for file in ['LiveModels.swift', 'LiveClassesService.swift', 'LiveVideoService.swift', 'LiveNotificationManager.swift', 'LiveClassesStore.swift']:
    source += (root / 'Model/LiveClasses' / file).read_text() + '\n'
source += r'''
@main struct Checks {
    @MainActor static func main() async throws {
        let id = UUID(), tutor = UUID()
        let lesson = LiveLesson(id: id, tutorID: tutor, subject: "Physics", topic: "Motion", grade: "Form 4", scheduledAt: Date(), durationMinutes: 60, status: .scheduled, recordingEnabled: true, recordingFolder: "Physics/Form 4/Motion")
        precondition(LiveLesson.lessonID(from: lesson.invitationURL) == id)
        for text in ["https://live/\(id)", "triconacademy://live/\(id)?token=secret", "triconacademy://live/\(id)#token=secret", "triconacademy://live/not-a-uuid", "triconacademy://secret@live/\(id)", "triconacademy://live:8080/\(id)", "triconacademy://live/extra/\(id)", "triconacademy://auth/\(id)"] {
            precondition(LiveLesson.lessonID(from: URL(string: text)!) == nil)
        }
        precondition(lesson.canManage(User(id: tutor, subjects: ["Physics"])))
        precondition(!lesson.canManage(User(id: tutor, subjects: ["Chemistry"])))
        precondition(!lesson.canManage(User(id: UUID(), subjects: ["Physics"])))
        precondition(lesson.canManage(User(id: UUID(), isAdmin: true)))
        let encoded = try JSONEncoder().encode(lesson)
        let decoded = try JSONDecoder().decode(LiveLesson.self, from: encoded)
        precondition(decoded == lesson)
        let service = LiveClassesService()
        try await service.save(lesson, editing: true)
        let fields = SupabaseClient.shared.payload
        precondition(fields["id"] == nil && fields["status"] == nil && fields["recording_active"] == nil)
        precondition(fields["recording_folder"] as? String == lesson.recordingFolder)
        SupabaseClient.shared.result = Data("[]".utf8)
        do { try await service.save(lesson, editing: true); preconditionFailure("A stale edit must report failure") } catch {}
        let room = LiveClassroomStore()
        await room.join(lesson)
        precondition(!room.connected && room.error != nil && room.participants.isEmpty)
        await room.control("mic")
        precondition(!room.mic)
        let sent = await room.send("Hello")
        precondition(!sent && room.messages.isEmpty)
        await room.leave()
        precondition(!room.connected)
        print("PASS: lesson decoding, safe deep links, tutor permissions, protected edit fields, stale edits, unconfigured video fails closed")
    }
}
'''
with tempfile.TemporaryDirectory() as directory:
    swift = Path(directory) / 'LiveChecks.swift'
    binary = Path(directory) / 'checks'
    swift.write_text(source)
    subprocess.run(['swiftc', '-parse-as-library', '-target', 'x86_64-apple-macos12', '-module-cache-path', '/tmp/tricon-swift-module-cache', str(swift), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
