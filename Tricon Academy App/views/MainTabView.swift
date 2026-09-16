import SwiftUI

/// Root shell for signed-in users (students, tutors, and admins).
/// Staff (tutor/admin) get an overview and an extra Content tab for uploads.
struct MainTabView: View {

    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedTab = 0

    private var isAdmin: Bool {
        authManager.currentUser?.isAdmin == true
    }

    private var isStaff: Bool {
        authManager.currentUser?.canManageContent == true
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

            NavigationView {
                BrowseView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label(isAdmin ? "Curriculum" : "Browse", systemImage: "square.grid.2x2.fill")
            }
            .tag(1)

            NavigationView {
                SavedItemsView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Saved", systemImage: "bookmark.fill")
            }
            .tag(2)

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
        .accentColor(AppTheme.brandBright)
        .tint(AppTheme.brandBright)
        // If a staff user logs out and a student logs in (or vice versa),
        // keep the selected tab in a valid range.
        .onChange(of: isStaff) { _ in
            selectedTab = 0
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AuthManager.shared)
    }
}
