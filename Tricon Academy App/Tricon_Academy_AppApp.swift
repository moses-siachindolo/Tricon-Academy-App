import SwiftUI

@main
struct Tricon_Academy_App: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var appSettings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoggedIn {
                    // Post-signup verification gates (student school info / tutor application).
                    if authManager.currentUser?.needsStudentOnboarding == true {
                        StudentWelcomeOnboardingView()
                    } else if authManager.currentUser?.needsTutorApplication == true {
                        NavigationView {
                            TutorApplicationView()
                        }
                        .navigationViewStyle(.stack)
                    } else if authManager.currentUser?.isAwaitingTutorApproval == true {
                        TutorPendingApprovalView()
                    } else if authManager.currentUser?.isTutorRejected == true {
                        TutorRejectedView()
                    } else {
                        MainTabView()
                    }
                } else {
                    NavigationView {
                        OnboardingView()
                    }
                    .navigationViewStyle(.stack)
                }
            }
            .environmentObject(authManager)
            .environmentObject(appSettings)
            .preferredColorScheme(appSettings.preferredColorScheme)
            .onAppear {
                appSettings.applyGlobally()
            }
            .onChange(of: appSettings.useDarkTheme) { _ in
                appSettings.applyGlobally()
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active && authManager.isLoggedIn {
                    StatsManager.shared.recordAppActive()
                }
            }
            .onOpenURL { url in
                authManager.handleOpenURL(url)
            }
            .sheet(isPresented: $authManager.needsPasswordResetCompletion) {
                ResetPasswordConfirmView()
                    .environmentObject(authManager)
                    .environmentObject(appSettings)
                    .preferredColorScheme(appSettings.preferredColorScheme)
            }
            .alert(
                "Reset link",
                isPresented: Binding(
                    get: { authManager.deepLinkError != nil },
                    set: { if !$0 { authManager.deepLinkError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { authManager.deepLinkError = nil }
            } message: {
                Text(authManager.deepLinkError ?? "")
            }
        }
    }
}
