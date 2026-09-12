"""Exercise production account-access checks with deterministic server responses."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
auth = (root / 'AuthManger.swift').read_text()

def method(start, end):
    return auth[auth.index(start):auth.index(end, auth.index(start))]

methods = method('    private func accessDeniedMessage', '    // MARK: - Register')
methods += method('    /// Runs only while the app is active;', '    /// Super-admin: strip tutor privileges')
source = r'''
import Foundation
struct User { let id: UUID }
struct RemoteProfile {
    var isAccountRemoved = false
    var isAccountBlocked = false
    var adminStatusReason: String? = nil
    var asUser: User
}
struct StoredAccount { let id: UUID; let asRemoteProfile: RemoteProfile; let asUser: User }
enum AcademySupport { static let phoneDisplay = "support"; static let email = "support@example.invalid" }
@MainActor final class FakeClient {
    var isConfigured = true
    var profiles: [RemoteProfile] = []
    var error: Error?
    var onSelect: (() -> Void)?
    var cleared = false
    func select(table: String, query: String) async throws -> [RemoteProfile] {
        onSelect?()
        if let error { throw error }
        return profiles
    }
    func clearSession() { cleared = true }
}
@MainActor final class AuthHarness {
    var currentUser: User?
    var authGeneration = 0
    var isLoggedIn = true
    var needsPasswordResetCompletion = true
    var deepLinkError: String? = "old error"
    var accountAccessMessage: String?
    var remembered = false
    var saved = false
    let client = FakeClient()
    let sessionKeychainKey = "test"
    func ensureValidCloudSession(forceRefresh: Bool) async throws {}
    func readFromKeychain(key: String) -> Data? { remembered ? Data() : nil }
    func loadAccounts() -> [StoredAccount] { [] }
    func saveSession(user: User, persist: Bool) { currentUser = user; remembered = persist; saved = true }
    func clearLocalLoginState() { currentUser = nil; isLoggedIn = false; authGeneration += 1; remembered = false }
'''
source += methods + '\n}\n'
source += r'''
@main struct Checks {
    @MainActor static func main() async {
        let user = User(id: UUID())
        for removed in [false, true] {
            let auth = AuthHarness()
            auth.currentUser = user
            auth.client.profiles = [RemoteProfile(isAccountRemoved: removed, isAccountBlocked: true,
                adminStatusReason: "Administrator reason", asUser: user)]
            await auth.refreshCurrentUserProfile()
            precondition(!auth.isLoggedIn && auth.currentUser == nil && auth.client.cleared)
            precondition(auth.accountAccessMessage!.contains(removed ? "removed" : "blocked"))
            precondition(auth.accountAccessMessage!.contains("Administrator reason"))
            precondition(auth.accountAccessMessage!.contains("signed out"))
            precondition(!auth.needsPasswordResetCompletion && auth.deepLinkError == nil)
        }
        let missing = AuthHarness()
        missing.currentUser = user
        await missing.refreshCurrentUserProfile()
        precondition(!missing.isLoggedIn && missing.accountAccessMessage != nil)
        let offline = AuthHarness()
        offline.currentUser = user
        offline.client.error = URLError(.notConnectedToInternet)
        await offline.refreshCurrentUserProfile()
        precondition(offline.isLoggedIn && offline.accountAccessMessage == nil && !offline.client.cleared)
        let allowed = AuthHarness()
        allowed.currentUser = user
        allowed.client.profiles = [RemoteProfile(asUser: user)]
        await allowed.refreshCurrentUserProfile()
        precondition(allowed.saved && allowed.isLoggedIn && !allowed.remembered)
        let stale = AuthHarness()
        stale.currentUser = user
        let other = User(id: UUID())
        stale.client.profiles = [RemoteProfile(isAccountBlocked: true, asUser: user)]
        stale.client.onSelect = { stale.currentUser = other; stale.authGeneration += 1 }
        await stale.refreshCurrentUserProfile()
        precondition(stale.currentUser?.id == other.id && stale.accountAccessMessage == nil)
        precondition(!stale.client.cleared)
        stale.client.onSelect = nil
        let cancelled = AuthHarness()
        cancelled.currentUser = user
        cancelled.client.profiles = [RemoteProfile(isAccountBlocked: true, asUser: user)]
        let task = Task { await cancelled.refreshCurrentUserProfile() }
        task.cancel()
        await task.value
        precondition(cancelled.isLoggedIn && cancelled.accountAccessMessage == nil)
        print("PASS: blocked/removed logout, admin reason, missing profile, offline preservation, Remember me, stale response and cancellation")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='tricon-account-checks-') as tmp:
    swift = Path(tmp) / 'Checks.swift'
    binary = Path(tmp) / 'checks'
    swift.write_text(source)
    subprocess.run(['swiftc', '-parse-as-library', '-module-cache-path', str(Path(tempfile.gettempdir()) / 'tricon-swift-module-cache'), str(swift), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
