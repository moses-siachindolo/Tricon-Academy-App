import SwiftUI

struct ProfileView: View {

    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var stats = StatsManager.shared
    @State private var showLogoutConfirm = false
    @State private var showUploadSheet = false

    private var accountTypeLabel: String {
        authManager.currentUser?.roleDisplayName ?? "Student"
    }

    private var canManageContent: Bool {
        authManager.currentUser?.canManageContent == true
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // MARK: Identity
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 88, height: 88)
                        Text(initials)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    .accessibilityHidden(true)

                    Text(authManager.currentUser?.fullName ?? "Student")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(authManager.currentUser?.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Text(accountTypeLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(canManageContent ? Color.green.opacity(0.15) : Color(.systemGray5))
                        .foregroundColor(canManageContent ? .green : .secondary)
                        .cornerRadius(20)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(authManager.currentUser?.fullName ?? "Student"), \(accountTypeLabel), \(authManager.currentUser?.email ?? "")")

                // MARK: Stats snapshot
                VStack(alignment: .leading, spacing: 12) {
                    Text("This week")
                        .font(.headline)

                    HStack(spacing: 10) {
                        profileStat(icon: "doc.text.fill", value: "\(stats.papersSolvedThisWeek)", label: "Papers", color: .blue)
                        profileStat(icon: "play.rectangle.fill", value: "\(stats.videosWatchedThisWeek)", label: "Videos", color: .purple)
                        profileStat(icon: "flame.fill", value: "\(stats.dayStreak)", label: "Streak", color: .orange)
                    }
                }
                .padding(.horizontal, 22)

                // MARK: Staff tools
                if canManageContent {
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
                    .padding(.horizontal, 22)
                }

                // MARK: Account
                VStack(spacing: 0) {
                    profileRow(icon: "person.fill", title: "Account type", value: accountTypeLabel)
                    Divider().padding(.leading, 52)
                    profileRow(
                        icon: "lock.shield.fill",
                        title: "Content upload",
                        value: canManageContent ? "Allowed" : "Students only view"
                    )
                    Divider().padding(.leading, 52)
                    profileRow(icon: "info.circle.fill", title: "About", value: "Tricon Academy 1.0")
                }
                .background(Color(.systemGray6))
                .cornerRadius(14)
                .padding(.horizontal, 22)

                Button(role: .destructive) {
                    showLogoutConfirm = true
                } label: {
                    Text("Log Out")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.red.opacity(0.12))
                        .foregroundColor(.red)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .accessibilityLabel("Log out")

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showUploadSheet) {
            UploadLessonView()
                .environmentObject(authManager)
        }
        .confirmationDialog("Log out of Tricon Academy?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Log Out", role: .destructive) {
                authManager.logout()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var initials: String {
        let name = authManager.currentUser?.fullName ?? "S"
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    @ViewBuilder
    private func profileStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }

    @ViewBuilder
    private func profileRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.green)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProfileView()
        }
        .environmentObject(AuthManager.shared)
    }
}
