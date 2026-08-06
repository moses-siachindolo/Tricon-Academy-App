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
            VStack(spacing: 20) {

                // MARK: Identity
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.brand, AppTheme.brandDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 88, height: 88)
                            .shadow(color: AppTheme.brand.opacity(0.30), radius: 14, x: 0, y: 8)
                        Text(initials)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .accessibilityHidden(true)

                    Text(authManager.currentUser?.fullName ?? "Student")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.ink)

                    Text(authManager.currentUser?.email ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.muted)

                    Text(accountTypeLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(canManageContent ? AppTheme.brandSoft : AppTheme.stroke)
                        .foregroundColor(canManageContent ? AppTheme.brandDeep : AppTheme.muted)
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(authManager.currentUser?.fullName ?? "Student"), \(accountTypeLabel), \(authManager.currentUser?.email ?? "")")

                // MARK: Tutor specialist scope
                if authManager.currentUser?.isTutor == true {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your specialist subjects")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.muted)
                        Text(authManager.currentUser?.managedSubjectsDisplay ?? "Not set")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.brandDeep)
                        Text("Upload and delete only for these courses. You can still browse every other subject.")
                            .font(.system(size: 12.5))
                            .foregroundColor(AppTheme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
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
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.brand, AppTheme.brandDeep],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: AppTheme.brand.opacity(0.25), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                }

                // MARK: Settings
                NavigationLink(destination: SettingsView()) {
                    HStack(spacing: 14) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.brand)
                            .frame(width: 24)
                        Text("Settings")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.ink)
                        Spacer()
                        Text("Theme")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.muted)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.muted.opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.stroke, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
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
                        Divider().padding(.leading, 52)
                        profileRow(
                            icon: "mappin.and.ellipse",
                            title: "District",
                            value: authManager.currentUser?.schoolDistrict?.isEmpty == false
                                ? (authManager.currentUser?.schoolDistrict ?? "—")
                                : "Not set"
                        )
                        Divider().padding(.leading, 52)
                        profileRow(
                            icon: "graduationcap.fill",
                            title: "Grade",
                            value: authManager.currentUser?.grade?.isEmpty == false
                                ? (authManager.currentUser?.grade ?? "—")
                                : "Not set"
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.stroke, lineWidth: 1)
                    )
                    .padding(.horizontal, AppTheme.horizontalPadding)
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
                    profileRow(icon: "bookmark.fill", title: "Saved items", value: "\(saved.items.count)")
                    Divider().padding(.leading, 52)
                    profileRow(icon: "info.circle.fill", title: "About", value: "Tricon Academy 1.0")
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.stroke, lineWidth: 1)
                )
                .padding(.horizontal, AppTheme.horizontalPadding)

                Button(role: .destructive) {
                    showLogoutConfirm = true
                } label: {
                    Text("Log Out")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppTheme.danger.opacity(0.10))
                        .foregroundColor(AppTheme.danger)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.top, 4)
                .accessibilityLabel("Log out")

                Spacer(minLength: 32)
            }
        }
        .background(AppTheme.canvas.ignoresSafeArea())
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

    private func profileRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.brand)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(AppTheme.ink)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.muted)
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
