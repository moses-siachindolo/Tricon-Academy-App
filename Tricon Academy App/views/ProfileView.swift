import SwiftUI

/// Profile — identity, shortcuts, and academic details in the upper half of the screen.
struct ProfileView: View {

    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var saved = SavedItemsManager.shared
    @State private var showLogoutConfirm = false
    @State private var showUploadSheet = false

    private let brand = AppTheme.brand
    private let brandDeep = AppTheme.brandDeep
    private let brandSoft = AppTheme.brandSoft
    private let canvas = AppTheme.canvas
    private let ink = AppTheme.ink
    private let muted = AppTheme.muted

    private var user: User? { authManager.currentUser }

    private var accountTypeLabel: String {
        user?.roleDisplayName ?? "Student"
    }

    private var canManageContent: Bool {
        user?.canManageContent == true
    }

    private var savedCount: Int { saved.items.count }

    private var settingsSubtitle: String {
        if user?.isStudent == true { return "Form and appearance" }
        if user?.isTutor == true { return "Subjects and appearance" }
        return "Appearance and account"
    }

    private var savedSubtitle: String {
        if savedCount == 0 { return "Papers, notes, and videos" }
        return savedCount == 1 ? "1 bookmarked resource" : "\(savedCount) bookmarked resources"
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard

                    if canManageContent {
                        uploadButton
                    }

                    shortcutsCard

                    if user?.isStudent == true {
                        academicProfileCard
                    } else if user?.isTutor == true {
                        teachingProfileCard
                    }

                    logoutButton

                    Spacer(minLength: max(20, geo.size.height * 0.36))
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .frame(minHeight: geo.size.height, alignment: .top)
            }
        }
        .background(
            ZStack {
                canvas.ignoresSafeArea()
                LinearGradient(
                    colors: [brandSoft.opacity(0.50), canvas, canvas],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        )
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

    // MARK: - Header

    private var headerCard: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .stroke(brand.opacity(0.22), lineWidth: 3)
                    .frame(width: 80, height: 80)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.brand, AppTheme.brandFillDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: brand.opacity(0.22), radius: 8, x: 0, y: 4)
                Text(initials)
                    .appFont(size: 24, weight: .bold, design: .rounded)
                    .foregroundColor(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(user?.fullName ?? "Student")
                    .appFont(size: 22, weight: .bold)
                    .foregroundColor(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(user?.email ?? "")
                    .appFont(size: 15, weight: .medium)
                    .foregroundColor(muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(accountTypeLabel)
                    .appFont(size: 12.5, weight: .semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(canManageContent ? brandSoft : AppTheme.fill)
                    .foregroundColor(canManageContent ? brandDeep : muted)
                    .clipShape(Capsule())
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(cardBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(user?.fullName ?? "Student"), \(accountTypeLabel), \(user?.email ?? "")")
    }

    // MARK: - Upload

    private var uploadButton: some View {
        Button {
            showUploadSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Upload lesson")
                    .appFont(size: 16, weight: .semibold)
            }
        }
        .buttonStyle(AppPrimaryButtonStyle())
    }

    // MARK: - Shortcuts

    private var shortcutsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Account")

            VStack(spacing: 0) {
                NavigationLink(destination: SettingsView()) {
                    shortcutRow(
                        icon: "gearshape.fill",
                        title: "Settings",
                        subtitle: settingsSubtitle
                    )
                }
                .buttonStyle(SoftPressStyle())

                Divider()
                    .padding(.leading, 62)

                NavigationLink(destination: SavedItemsView()) {
                    shortcutRow(
                        icon: "bookmark.fill",
                        title: "Saved resources",
                        subtitle: savedSubtitle,
                        badge: savedCount > 0 ? "\(savedCount)" : nil
                    )
                }
                .buttonStyle(SoftPressStyle())
            }
            .background(cardBackground)
        }
    }

    // MARK: - Academic profile (students)

    private var academicProfileCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Academic Profile")

            VStack(spacing: 0) {
                detailRow(
                    icon: "building.columns.fill",
                    title: "School",
                    value: nonEmpty(user?.school) ?? "Not set"
                )
                Divider().padding(.leading, 62)
                detailRow(
                    icon: "map.fill",
                    title: "District",
                    value: nonEmpty(user?.schoolDistrict) ?? "Not set"
                )
                Divider().padding(.leading, 62)
                detailRow(
                    icon: "graduationcap.fill",
                    title: "Form",
                    value: nonEmpty(user?.grade) ?? "Not set"
                )
            }
            .background(cardBackground)
        }
    }

    // MARK: - Teaching profile (tutors)

    private var teachingProfileCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Academic Profile")

            VStack(spacing: 0) {
                detailRow(
                    icon: "lock.fill",
                    title: "Majors",
                    value: user?.managedSubjectsDisplay ?? "Not set"
                )
                if let institution = nonEmpty(user?.lastInstitution) {
                    Divider().padding(.leading, 62)
                    detailRow(
                        icon: "building.columns.fill",
                        title: "Institution",
                        value: institution
                    )
                }
                if let education = nonEmpty(user?.highestEducation) {
                    Divider().padding(.leading, 62)
                    detailRow(
                        icon: "graduationcap.fill",
                        title: "Education",
                        value: education
                    )
                }
            }
            .background(cardBackground)
        }
    }

    // MARK: - Log out

    private var logoutButton: some View {
        Button {
            showLogoutConfirm = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                Text("Log Out")
                    .appFont(size: 16, weight: .semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(AppTheme.dangerSoft)
            .foregroundColor(AppTheme.danger)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                    .stroke(AppTheme.danger.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel("Log out")
        .padding(.top, 4)
    }

    // MARK: - Pieces

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
            .fill(AppTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .stroke(brand.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: AppTheme.shadow.opacity(0.55), radius: 8, x: 0, y: 3)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .appFont(size: 12, weight: .semibold)
            .tracking(0.6)
            .foregroundColor(muted)
            .padding(.horizontal, 4)
    }

    private func symbolWell(_ name: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous)
                .fill(brandSoft)
                .frame(width: 36, height: 36)
            Image(systemName: name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(brand)
                .symbolRenderingMode(.hierarchical)
        }
    }

    private func shortcutRow(icon: String, title: String, subtitle: String, badge: String? = nil) -> some View {
        HStack(spacing: 14) {
            symbolWell(icon)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .appFont(size: 16, weight: .semibold)
                    .foregroundColor(ink)
                Text(subtitle)
                    .appFont(size: 13.5, weight: .medium)
                    .foregroundColor(muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let badge {
                Text(badge)
                    .appFont(size: 12, weight: .bold, design: .rounded)
                    .foregroundColor(brandDeep)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(brandSoft))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.subtle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            symbolWell(icon)

            Text(title)
                .appFont(size: 16, weight: .medium)
                .foregroundColor(ink)

            Spacer(minLength: 8)

            Text(value)
                .appFont(size: 15, weight: .semibold)
                .foregroundColor(muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }

    private var initials: String {
        let name = user?.fullName ?? "S"
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
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
