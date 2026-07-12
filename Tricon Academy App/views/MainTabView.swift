import SwiftUI

/// Root shell for signed-in users (students, tutors, and admins).
/// Staff (tutor/admin) get an extra "Manage" tab for uploads; students do not.
struct MainTabView: View {

    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedTab = 0

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
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)

            NavigationView {
                BrowseView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Browse", systemImage: "square.grid.2x2.fill")
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
                    Label("Manage", systemImage: "arrow.up.doc.fill")
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
        .accentColor(.green)
        // If a staff user logs out and a student logs in (or vice versa),
        // keep the selected tab in a valid range.
        .onChange(of: isStaff) { _ in
            if selectedTab > (isStaff ? 4 : 3) {
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
