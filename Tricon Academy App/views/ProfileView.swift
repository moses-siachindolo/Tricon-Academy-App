import SwiftUI

struct ProfileView: View {

    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var saved = SavedItemsManager.shared
    @State private var showLogoutConfirm = false
    @State private var showUploadSheet = false

    private var accountTypeLabel: String {
        authManager.currentUser?.roleDisplayName ?? "Student"
    }

    private var canManageContent: Bool {
        authManager.currentUser?.canManageContent == true
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {

                // MARK: Compact identity
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.brand, AppTheme.brandDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .shadow(color: AppTheme.brand.opacity(0.22), radius: 8, x: 0, y: 4)
                        Text(initials)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(authManager.currentUser?.fullName ?? "Student")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.ink)
                            .lineLimit(1)

                        Text(authManager.currentUser?.email ?? "")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.muted)
                            .lineLimit(1)

                        Text(accountTypeLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(canManageContent ? AppTheme.brandSoft : AppTheme.stroke)
                            .foregroundColor(canManageContent ? AppTheme.brandDeep : AppTheme.muted)
                            .clipShape(Capsule())
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.top, 8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(authManager.currentUser?.fullName ?? "Student"), \(accountTypeLabel), \(authManager.currentUser?.email ?? "")")

                // MARK: Tutor specialist scope (admin-locked)
                if authManager.currentUser?.isTutor == true {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("Approved majors")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.muted)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(AppTheme.muted)
                        }
                        Text(authManager.currentUser?.managedSubjectsDisplay ?? "Not set")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.brandDeep)
                        Text("Admin-approved only. Request more subjects in Settings.")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.stroke, lineWidth: 1)
                    )
                    .padding(.horizontal, AppTheme.horizontalPadding)
                }

                // MARK: Staff tools
                if canManageContent {
                    Button {
                        showUploadSheet = true
                    } label: {
                        Label("Upload Document or Lesson", systemImage: "arrow.up.doc.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.brand, AppTheme.brandDeep],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: AppTheme.brand.opacity(0.22), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                }

                // MARK: Quick links
                VStack(spacing: 0) {
                    NavigationLink(destination: SettingsView()) {
                        linkRow(
                            icon: "gearshape.fill",
                            title: "Settings",
                            value: authManager.currentUser?.isTutor == true
                                ? "Request access · Theme"
                                : (authManager.currentUser?.isStudent == true
                                   ? "Form · Theme"
                                   : "Theme")
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 48)

                    profileRow(
                        icon: "bookmark.fill",
                        title: "Saved items",
                        value: "\(saved.items.count)"
                    )
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.stroke, lineWidth: 1)
                )
                .padding(.horizontal, AppTheme.horizontalPadding)

                // MARK: School (students)
                if authManager.currentUser?.isStudent == true {
                    VStack(spacing: 0) {
                        profileRow(
                            icon: "building.2.fill",
                            title: "School",
                            value: authManager.currentUser?.school?.isEmpty == false
                                ? (authManager.currentUser?.school ?? "—")
                                : "Not set"
                        )
                        Divider().padding(.leading, 48)
                        profileRow(
                            icon: "mappin.and.ellipse",
                            title: "District",
                            value: authManager.currentUser?.schoolDistrict?.isEmpty == false
                                ? (authManager.currentUser?.schoolDistrict ?? "—")
                                : "Not set"
                        )
                        Divider().padding(.leading, 48)
                        profileRow(
                            icon: "graduationcap.fill",
                            title: "Grade",
                            value: authManager.currentUser?.grade?.isEmpty == false
                                ? (authManager.currentUser?.grade ?? "—")
                                : "Not set"
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.stroke, lineWidth: 1)
                    )
                    .padding(.horizontal, AppTheme.horizontalPadding)
                }

                Button(role: .destructive) {
                    showLogoutConfirm = true
                } label: {
                    Text("Log Out")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(AppTheme.dangerSoft)
                        .foregroundColor(AppTheme.danger)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.top, 2)
                .accessibilityLabel("Log out")

                Spacer(minLength: 24)
            }
        }
        .appScreen()
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

    private func linkRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.brand)
                .frame(width: 22)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.ink)
            Spacer()
            Text(value)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(AppTheme.muted)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.subtle)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func profileRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.brand)
                .frame(width: 22)
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.ink)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.muted)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
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
