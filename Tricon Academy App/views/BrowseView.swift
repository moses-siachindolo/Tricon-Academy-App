import SwiftUI

/// Primary Browse tab: students land on their registered form only;
/// tutors pick a form then see specialist majors; admins see full catalogue.
struct BrowseView: View {

    @EnvironmentObject private var authManager: AuthManager

    private let brand = AppTheme.brand
    private let brandDeep = AppTheme.brandDeep
    private let brandSoft = AppTheme.brandSoft
    private let canvas = AppTheme.canvas
    private let ink = AppTheme.ink
    private let muted = AppTheme.muted

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

    // MARK: - Staff: form picker (uniform brand)

    private var staffBrowse: some View {
        GeometryReader { geo in
            let hPad: CGFloat = 20
            let gap: CGFloat = 12
            let headerH: CGFloat = 88
            let topPad: CGFloat = 8
            let bottomPad: CGFloat = 16
            let levels = Level.activeCases
            let rows = max(1, Int(ceil(Double(levels.count) / 2.0)))
            let used = topPad + headerH + bottomPad
            let gridH = max(260, geo.size.height - used)
            let cardH = max(120, (gridH - CGFloat(rows - 1) * gap) / CGFloat(rows))

            VStack(alignment: .leading, spacing: 16) {
                staffHeader
                    .frame(height: headerH, alignment: .top)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: gap),
                        GridItem(.flexible(), spacing: gap)
                    ],
                    spacing: gap
                ) {
                    ForEach(levels) { level in
                        NavigationLink {
                            SubjectListView(level: level)
                        } label: {
                            staffFormCard(level, height: cardH)
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, hPad)
            .padding(.top, topPad)
            .padding(.bottom, bottomPad)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .background(brandWash)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Browse")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(ink)
            }
        }
    }

    private var staffHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [brand, brandDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: brand.opacity(0.28), radius: 10, x: 0, y: 5)
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(isTutor ? "Browse by form" : "Browse curriculum")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(ink)
                    Text(isTutor
                         ? "Pick a form to open your specialist subjects"
                         : "Choose a form, then open a subject")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(muted)
                }
            }

            Text("Forms")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(brandDeep)
                .tracking(0.6)
                .textCase(.uppercase)
                .padding(.top, 4)
        }
    }

    private var browseSubjectCountLabel: String {
        if isTutor {
            let n = authManager.currentUser?.managedSubjects.count ?? 0
            if n == 0 { return "Set majors in Settings" }
            return "\(n) specialist subject\(n == 1 ? "" : "s")"
        }
        return "\(allSubjects.count) subjects"
    }

    private func staffFormCard(_ level: Level, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(brandSoft)
                        .frame(width: 48, height: 48)
                    Text(level.shortLabel)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(brandDeep)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(brand.opacity(0.45))
                    .padding(7)
                    .background(Circle().fill(brandSoft.opacity(0.7)))
            }

            Spacer(minLength: 12)

            Text(level.rawValue)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ink)

            Text(browseSubjectCountLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(muted)
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(brand.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: brand.opacity(0.06), radius: 14, x: 0, y: 6)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
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
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(ink)

            Text("Choose Form 1–4 in Settings so we can show the right papers, notes, and videos.")
                .font(.system(size: 14.5, weight: .medium))
                .foregroundColor(muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            NavigationLink(destination: SettingsView()) {
                Text("Open Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [brand, brandDeep],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: brand.opacity(0.30), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 40)
            .padding(.top, 4)

            Spacer()
        }
        .background(brandWash)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Browse")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(ink)
            }
        }
    }

    private var brandWash: some View {
        ZStack {
            canvas.ignoresSafeArea()
            LinearGradient(
                colors: [brandSoft.opacity(0.55), canvas, canvas],
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
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(brandSoft)
                                .frame(width: 48, height: 48)
                            Image(systemName: subject.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(brandDeep)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Choose a form")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(ink)
                            Text("Open \(subject.name) for Form 1–4")
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundColor(muted)
                        }
                    }
                    .padding(.horizontal, 20)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        ForEach(Level.activeCases) { level in
                            NavigationLink {
                                destination(for: level)
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(level.shortLabel)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(brandDeep)
                                        .frame(width: 40, height: 40)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(brandSoft))
                                    Text(level.rawValue)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(ink)
                                    Text(subject.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(muted)
                                        .lineLimit(1)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(AppTheme.card)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(brand.opacity(0.10), lineWidth: 1)
                                )
                                .shadow(color: brand.opacity(0.06), radius: 12, x: 0, y: 5)
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 12)
                .padding(.bottom, 28)
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
