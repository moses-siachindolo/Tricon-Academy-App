import SwiftUI

/// Primary Browse tab: students land on their registered form only;
/// tutors pick a form then see specialist majors; admins see full catalogue.
struct BrowseView: View {

    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let brand = AppTheme.brand
    private let brandDeep = AppTheme.brandDeep
    private let brandSoft = AppTheme.brandSoft
    private let canvas = AppTheme.canvas
    private let ink = AppTheme.ink
    private let muted = AppTheme.muted
    private let iconGreen = AppTheme.iconGreen
    private let secondary = AppTheme.secondaryInk
    private let well = AppTheme.iconWell
    private let cardLine = AppTheme.cardLine

    private var studentLevel: Level? {
        authManager.currentUser?.studentLevel
    }

    private var isTutor: Bool {
        authManager.currentUser?.isTutor == true
    }

    var body: some View {
        Group {
            if authManager.currentUser?.isStudent == true, let level = studentLevel {
                SubjectListView(level: level)
            } else if authManager.currentUser?.isStudent == true {
                missingFormPrompt
            } else {
                staffBrowse
            }
        }
    }

    // MARK: - Staff: form picker (compact — ~half screen, matches subject grid)

    private var staffBrowse: some View {
        // Fixed compact cards: 2×2 grid stays in upper half on all phones.
        let hPad: CGFloat = 16
        let gap: CGFloat = 10
        let cardH: CGFloat = 110

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                staffHeader

                Text("Forms")
                    .appFont(size: 11, weight: .bold)
                    .foregroundColor(iconGreen)
                    .tracking(0.4)
                    .textCase(.uppercase)

                LazyVGrid(
                    columns: dynamicTypeSize.isAccessibilitySize
                        ? [GridItem(.flexible())]
                        : [GridItem(.adaptive(minimum: 145), spacing: gap)],
                    spacing: gap
                ) {
                    ForEach(Level.activeCases) { level in
                        NavigationLink {
                            SubjectListView(level: level)
                        } label: {
                            staffFormCard(level, height: cardH)
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, hPad)
            .padding(.top, 8)
            .padding(.bottom, 14)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(brandWash)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(authManager.currentUser?.isAdmin == true ? "Curriculum" : "Browse")
                    .appFont(size: 16, weight: .semibold)
                    .foregroundColor(ink)
            }
        }
    }

    private var staffHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.brand, AppTheme.brandFillDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: brand.opacity(0.2), radius: 5, x: 0, y: 2)
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(isTutor ? "Browse by form" : "Browse curriculum")
                    .appFont(size: 17, weight: .bold)
                    .foregroundColor(ink)
                    .lineLimit(1)
                Text(isTutor
                     ? "Open specialist subjects by form"
                     : "Choose a form, then a subject")
                    .appFont(size: 12, weight: .medium)
                    .foregroundColor(secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private var browseSubjectCountLabel: String {
        if isTutor {
            let n = authManager.currentUser?.managedSubjects.count ?? 0
            if n == 0 { return "Set majors in Settings" }
            return "\(n) specialist\(n == 1 ? "" : "s")"
        }
        return "\(allSubjects.count) subjects"
    }

    private func staffFormCard(_ level: Level, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(level.shortLabel)
                .appFont(size: 13, weight: .bold, design: .rounded)
                .foregroundColor(iconGreen)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous)
                        .fill(well)
                )

            Text(level.rawValue)
                .appFont(size: 14.5, weight: .semibold)
                .foregroundColor(ink)
                .lineLimit(1)

            Text(browseSubjectCountLabel)
                .appFont(size: 11, weight: .medium)
                .foregroundColor(secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(cardLine, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(level.rawValue). \(browseSubjectCountLabel).")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Missing form

    private var missingFormPrompt: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(brandSoft)
                    .frame(width: 88, height: 88)
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(brandDeep)
            }

            Text("Set your form")
                .appFont(size: 22, weight: .bold)
                .foregroundColor(ink)

            Text("Choose Form 1–4 in Settings so we can show the right papers, notes, and videos.")
                .appFont(size: 14.5, weight: .medium)
                .foregroundColor(muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            NavigationLink(destination: SettingsView()) {
                Text("Open Settings")
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .padding(.horizontal, 40)
            .padding(.top, 4)

            Spacer()
        }
        .background(brandWash)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(authManager.currentUser?.isAdmin == true ? "Curriculum" : "Browse")
                    .appFont(size: 17, weight: .semibold)
                    .foregroundColor(ink)
            }
        }
    }

    private var brandWash: some View {
        ZStack {
            canvas.ignoresSafeArea()
            LinearGradient(
                colors: [brandSoft.opacity(0.38), canvas, canvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

/// After a search hit on a subject, let the user pick which level to open.
/// Students skip the picker and open their form directly.
struct SubjectLevelPickerView: View {

    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let subject: Subject

    private let brand = AppTheme.brand
    private let brandDeep = AppTheme.brandDeep
    private let brandSoft = AppTheme.brandSoft
    private let canvas = AppTheme.canvas
    private let ink = AppTheme.ink
    private let muted = AppTheme.muted

    var body: some View {
        if authManager.currentUser?.isStudent == true,
           let level = authManager.currentUser?.studentLevel {
            destination(for: level)
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous)
                                .fill(brandSoft)
                                .frame(width: 40, height: 40)
                            Image(systemName: subject.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(brandDeep)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Choose a form")
                                .appFont(size: 17, weight: .bold)
                                .foregroundColor(ink)
                            Text("Open \(subject.name) · Form 1–4")
                                .appFont(size: 12, weight: .medium)
                                .foregroundColor(muted)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 16)

                    Text("Forms")
                        .appFont(size: 11, weight: .bold)
                        .foregroundColor(brandDeep)
                        .tracking(0.4)
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)

                    LazyVGrid(
                        columns: dynamicTypeSize.isAccessibilitySize
                            ? [GridItem(.flexible())]
                            : [GridItem(.adaptive(minimum: 145), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(Level.activeCases) { level in
                            NavigationLink {
                                destination(for: level)
                            } label: {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(level.shortLabel)
                                        .appFont(size: 13, weight: .bold, design: .rounded)
                                        .foregroundColor(brandDeep)
                                        .frame(width: 28, height: 28)
                                        .background(
                                            RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous)
                                                .fill(brandSoft)
                                        )

                                    Spacer(minLength: 8)

                                    Text(level.rawValue)
                                        .appFont(size: 14.5, weight: .semibold)
                                        .foregroundColor(ink)
                                        .lineLimit(1)
                                    Text(subject.name)
                                        .appFont(size: 11, weight: .medium)
                                        .foregroundColor(muted)
                                        .lineLimit(1)
                                        .padding(.top, 3)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                                        .fill(AppTheme.card)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                                        .stroke(brand.opacity(0.10), lineWidth: 1)
                                )
                                .shadow(color: brand.opacity(0.035), radius: 6, x: 0, y: 2)
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .background(
                ZStack {
                    canvas.ignoresSafeArea()
                    LinearGradient(
                        colors: [brandSoft.opacity(0.55), canvas, canvas],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
            )
            .navigationTitle(subject.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func destination(for level: Level) -> some View {
        if subject.name == "Optionals" {
            OptionalsListView(level: level)
        } else {
            ContentHubView(level: level, subject: subject)
        }
    }
}

struct BrowseView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BrowseView()
        }
        .environmentObject(AuthManager.shared)
    }
}
