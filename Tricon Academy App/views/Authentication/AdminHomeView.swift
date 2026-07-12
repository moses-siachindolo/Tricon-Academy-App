import SwiftUI

/// Content management home for tutors and admins.
/// Embedded as a tab in `MainTabView` so staff still have full app access
/// (Home, Browse, Saved, Profile) plus upload tools.
struct AdminHomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showUploadSheet = false

    private var roleTitle: String {
        authManager.currentUser?.roleDisplayName ?? "Staff"
    }

    private var welcomeName: String {
        authManager.currentUser?.fullName ?? roleTitle
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {

                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome, \(welcomeName)")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("You’re signed in as \(roleTitle). Upload documents and lessons, and use every other tab like a student to review content.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)

                // Role badge
                HStack(spacing: 10) {
                    Image(systemName: authManager.currentUser?.isAdmin == true ? "shield.fill" : "person.crop.circle.badge.checkmark")
                        .foregroundColor(.green)
                    Text(roleTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("Content access")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(Color.green.opacity(0.1))
                .cornerRadius(14)
                .padding(.horizontal, 22)

                // Actions
                VStack(spacing: 12) {
                    Button {
                        showUploadSheet = true
                    } label: {
                        Label("Upload Document or Lesson", systemImage: "arrow.up.doc.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }

                    NavigationLink(destination: BrowseView()) {
                        Label("Browse published content", systemImage: "square.grid.2x2.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)

                // Tips
                VStack(alignment: .leading, spacing: 10) {
                    Text("Staff tools")
                        .font(.headline)

                    staffTip(
                        icon: "doc.badge.plus",
                        title: "Documents",
                        detail: "Upload PDFs, past papers, and study notes for any level and subject."
                    )
                    staffTip(
                        icon: "video.badge.plus",
                        title: "Video lessons",
                        detail: "Attach a video file with title, topic, and description."
                    )
                    staffTip(
                        icon: "person.2.fill",
                        title: "Student experience",
                        detail: "Use Home, Browse, and Saved tabs to see content the way learners do."
                    )
                }
                .padding(.horizontal, 22)

                Spacer(minLength: 24)
            }
        }
        .navigationTitle("Manage")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showUploadSheet) {
            UploadLessonView()
                .environmentObject(authManager)
        }
    }

    @ViewBuilder
    private func staffTip(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.green)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }
}

struct AdminHomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AdminHomeView()
        }
        .environmentObject(AuthManager.shared)
    }
}
