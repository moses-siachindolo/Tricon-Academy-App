import SwiftUI

@main
struct Tricon_Academy_App: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var liveClasses = LiveClassesStore.shared
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
                LiveNotificationManager.shared.install()
                LiveNotificationManager.shared.openLesson = { liveClasses.pendingLessonID = $0 }
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
            .task(id: "\(scenePhase == .active)-\(authManager.currentUser?.id.uuidString ?? "signed-out")") {
                if scenePhase == .active && authManager.isLoggedIn {
                    await authManager.monitorAccountAccess()
                }
            }
            .task(id: "live-\(scenePhase)-\(authManager.currentUser?.id.uuidString ?? "signed-out")") {
                liveClasses.setAccount(authManager.currentUser?.id)
                guard scenePhase == .active, authManager.isLoggedIn else { return }
                while !Task.isCancelled {
                    await liveClasses.refresh()
                    do { try await Task.sleep(nanoseconds: 30_000_000_000) } catch { break }
                }
            }
            .onOpenURL { url in
                if let id = LiveLesson.lessonID(from: url) { liveClasses.pendingLessonID = id }
                else if url.host != "live" { authManager.handleOpenURL(url) }
            }
            .sheet(isPresented: $authManager.needsPasswordResetCompletion) {
                ResetPasswordConfirmView()
                    .environmentObject(authManager)
                    .environmentObject(appSettings)
                    .preferredColorScheme(appSettings.preferredColorScheme)
            }
            .alert(
                authManager.accountAccessMessage == nil ? "Reset link" : "Account access",
                isPresented: Binding(
                    get: { authManager.accountAccessMessage != nil || authManager.deepLinkError != nil },
                    set: { if !$0 {
                        authManager.accountAccessMessage = nil
                        authManager.deepLinkError = nil
                    } }
                )
            ) {
                Button("OK", role: .cancel) {
                    authManager.accountAccessMessage = nil
                    authManager.deepLinkError = nil
                }
            } message: {
                Text(authManager.accountAccessMessage ?? authManager.deepLinkError ?? "")
            }
        }
    }
}
