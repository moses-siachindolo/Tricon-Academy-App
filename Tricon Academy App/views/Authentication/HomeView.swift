import SwiftUI

struct HomeView: View {

    @EnvironmentObject private var authManager: AuthManager
    @Binding var selectedTab: Int

    @State private var searchText = ""
    @State private var showUploadSheet = false

    // MARK: - Brand palette

    private let brand = AppTheme.brand
    private let brandDeep = AppTheme.brandDeep
    private let brandSoft = AppTheme.brandSoft
    private let canvas = AppTheme.canvas
    private let ink = AppTheme.ink
    private let muted = AppTheme.muted

    /// Profile tab index: staff have Manage at 3, so Profile is 4.
    private var profileTabIndex: Int {
        authManager.currentUser?.canManageContent == true ? 4 : 3
    }

    private var manageTabIndex: Int { 3 }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    init(selectedTab: Binding<Int> = .constant(0)) {
        _selectedTab = selectedTab
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredLevels: [Level] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return Level.activeCases.filter { $0.rawValue.localizedCaseInsensitiveContains(q) }
    }

    private var filteredSubjects: [Subject] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let core = allSubjects.filter { $0.name.localizedCaseInsensitiveContains(q) }
        let optionals = optionalSubjects.filter { $0.name.localizedCaseInsensitiveContains(q) }
        return core + optionals
    }
 
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {

                header
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.top, 8)

                if authManager.currentUser?.canManageContent == true {
                    staffActions
                        .padding(.horizontal, AppTheme.horizontalPadding)
                }

                searchBar
                    .padding(.horizontal, AppTheme.horizontalPadding)

                if isSearching {
                    searchResultsSection
                } else {
                    gradesSection
                    librarySection
                    quickAccessSection
                }
            }
            .padding(.bottom, 28)
        }
        .background(canvas.ignoresSafeArea())
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            StatsManager.shared.recordAppActive()
            // Warm the offline library catalogue before the user opens Library
            // (avoids static re-entry when NavigationLink destinations evaluate).
            TriconAcademyLibrary.preload()
        }
        .sheet(isPresented: $showUploadSheet) {
            UploadLessonView()
                .environmentObject(authManager)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(muted)
                Text(authManager.currentUser?.fullName ?? "Student")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(ink)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                selectedTab = profileTabIndex
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [brand, brandDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: brand.opacity(0.28), radius: 10, x: 0, y: 5)

                    Text(initials)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open profile")
        }
    }

    private var staffActions: some View {
        HStack(spacing: 10) {
            Button {
                showUploadSheet = true
            } label: {
                Label("Upload", systemImage: "arrow.up.doc.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        LinearGradient(
                            colors: [brand, brandDeep],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: brand.opacity(0.25), radius: 10, x: 0, y: 5)
            }

            Button {
                selectedTab = manageTabIndex
            } label: {
                Label("Manage", systemImage: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(brandSoft)
                    .foregroundColor(brandDeep)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(brand.opacity(0.18), lineWidth: 1)
                    )
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(muted)
                .accessibilityHidden(true)

            TextField("Search subjects, levels, topics", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(ink)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            if isSearching {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(muted.opacity(0.7))
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    // MARK: - Grades (simple modern squares)

    private var gradesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            LevelPickerHeader(
                title: "Your grades",
                subtitle: "Select a form to open subjects, papers, notes, and videos."
            )
            .padding(.horizontal, AppTheme.horizontalPadding)

            LevelPickerGrid { level in
                SubjectListView(level: level)
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
        }
    }

    // MARK: - Tricon Academy Library (Home only)

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tricon Academy Library")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ink)
                .padding(.horizontal, AppTheme.horizontalPadding)

            NavigationLink {
                // Sample catalogue + admin-approved staff books.
                // Tutor submissions stay hidden until an admin verifies them.
                TriconAcademyLibraryView()
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(brandSoft)
                            .frame(width: 52, height: 52)
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(brandDeep)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Browse the library")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ink)
                        Text("Tech · Science · Business · Stories")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(muted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(muted.opacity(0.75))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(brand.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppTheme.horizontalPadding)
        }
        .padding(.top, 2)
    }

    // MARK: - Quick access (compact)

    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick access")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ink)
                .padding(.horizontal, AppTheme.horizontalPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    quickChip(
                        icon: "doc.text.fill",
                        title: "Papers",
                        color: Color(red: 0.20, green: 0.48, blue: 0.92),
                        destination: BrowseLevelsView(
                            title: "Papers",
                            subtitle: "Choose a level to browse past papers.",
                            targetTab: 0
                        )
                    )
                    quickChip(
                        icon: "note.text",
                        title: "Notes",
                        color: Color(red: 0.10, green: 0.62, blue: 0.55),
                        destination: BrowseLevelsView(
                            title: "Notes",
                            subtitle: "Choose a level to browse notes.",
                            targetTab: 1
                        )
                    )
                    quickChip(
                        icon: "play.rectangle.fill",
                        title: "Videos",
                        color: Color(red: 0.52, green: 0.32, blue: 0.88),
                        destination: BrowseLevelsView(
                            title: "Videos",
                            subtitle: "Choose a level to browse videos.",
                            targetTab: 2
                        )
                    )

                    Button {
                        selectedTab = 2
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Saved")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.95, green: 0.48, blue: 0.18))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(Color(red: 0.95, green: 0.48, blue: 0.18).opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
            }
        }
        .padding(.top, 4)
    }

    private func quickChip<Destination: View>(
        icon: String,
        title: String,
        color: Color,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Capsule().fill(color.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search results

    @ViewBuilder
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if filteredLevels.isEmpty && filteredSubjects.isEmpty {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(brandSoft)
                            .frame(width: 64, height: 64)
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(brandDeep)
                    }
                    Text("No results for “\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))”")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ink)
                    Text("Try a subject like Physics, or a level like Form 1.")
                        .font(.system(size: 13))
                        .foregroundColor(muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
                .padding(.horizontal, AppTheme.horizontalPadding)
            } else {
                if !filteredLevels.isEmpty {
                    Text("Levels")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(ink)
                        .padding(.horizontal, AppTheme.horizontalPadding)

                    VStack(spacing: 12) {
                        ForEach(filteredLevels) { level in
                            NavigationLink(destination: SubjectListView(level: level)) {
                                LevelTile(level: level, style: .row)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                }

                if !filteredSubjects.isEmpty {
                    Text("Subjects")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(ink)
                        .padding(.horizontal, AppTheme.horizontalPadding)

                    VStack(spacing: 10) {
                        ForEach(filteredSubjects) { subject in
                            NavigationLink(destination: SubjectLevelPickerView(subject: subject)) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(subject.swiftUIColor.opacity(0.14))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: subject.icon)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(subject.swiftUIColor)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(subject.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(ink)
                                        Text("Choose a level to open")
                                            .font(.system(size: 12))
                                            .foregroundColor(muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(muted.opacity(0.7))
                                }
                                .padding(12)
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
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                }
            }
        }
    }

    private var initials: String {
        let name = authManager.currentUser?.fullName ?? "S"
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HomeView()
        }
        .environmentObject(AuthManager.shared)
    }
}
