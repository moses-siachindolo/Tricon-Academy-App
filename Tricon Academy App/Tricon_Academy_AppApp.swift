import SwiftUI

@main
struct Tricon_Academy_App: App {
    @StateObject private var authManager = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoggedIn {
                    // All roles share the main app. Tutors/admins additionally
                    // see the Manage tab (uploads). Students do not.
                    MainTabView()
                } else {
                    NavigationView {
                        OnboardingView()
                    }
                    .navigationViewStyle(.stack)
                }
            }
            .environmentObject(authManager)
        }
    }
}
