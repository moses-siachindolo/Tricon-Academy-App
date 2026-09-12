import SwiftUI

/// Root shell for signed-in users (students, tutors, and admins).
/// Staff (tutor/admin) get an overview and an extra Content tab for uploads.
/// Only students get Browse. Staff use Live Lessons in place of Saved.
struct MainTabView: View {

    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject private var liveClasses = LiveClassesStore.shared
    @State private var selectedTab = 0

    private var isAdmin: Bool {
        authManager.currentUser?.isAdmin == true
    }

    private var isStudent: Bool {
        authManager.currentUser?.isStudent == true
    }

    private var isStaff: Bool {
        authManager.currentUser?.canManageContent == true
    }

    private var hasLiveLessonsTab: Bool {
        isAdmin || authManager.currentUser?.isTutor == true
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                HomeView(selectedTab: $selectedTab)
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label(isStaff ? "Overview" : "Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
            }
            .tag(0)

            if isStudent {
                NavigationView {
                    BrowseView()
                }
                .navigationViewStyle(.stack)
                .tabItem {
                    Label("Browse", systemImage: "square.grid.2x2.fill")
                }
                .tag(1)
            }

            if hasLiveLessonsTab {
                NavigationView {
                    LiveClassesView()
                }
                .navigationViewStyle(.stack)
                .tabItem {
                    Label("Live Lessons", systemImage: selectedTab == 2 ? "video.fill" : "video")
                }
                .tag(2)
            } else {
                NavigationView {
                    SavedItemsView()
                }
                .navigationViewStyle(.stack)
                .tabItem {
                    Label("Saved", systemImage: "bookmark.fill")
                }
                .tag(2)
            }

            if isStaff {
                NavigationView {
                    AdminHomeView()
                }
                .navigationViewStyle(.stack)
                .tabItem {
                    Label("Content", systemImage: "arrow.up.doc.fill")
                }
                .tag(3)
            }

            NavigationView {
                ProfileView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag(isStaff ? 4 : 3)
        }
        .sheet(isPresented: Binding(get: { liveClasses.pendingLessonID != nil }, set: { if !$0 { liveClasses.pendingLessonID = nil } })) {
            NavigationView {
                if let id = liveClasses.pendingLessonID {
                    LiveLessonDetail(lessonID: id)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { liveClasses.pendingLessonID = nil } } }
                }
            }.navigationViewStyle(.stack)
        }
        .accentColor(AppTheme.brandBright)
        .tint(AppTheme.brandBright)
        // If a staff user logs out and a student logs in (or vice versa),
        // keep the selected tab in a valid range. Only students have Browse.
        .onChange(of: isStaff) { _ in
            selectedTab = 0
        }
        .onChange(of: isStudent) { student in
            if !student && selectedTab == 1 {
                selectedTab = 0
            }
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AuthManager.shared)
    }
}
