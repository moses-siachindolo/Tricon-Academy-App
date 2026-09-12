import SwiftUI

struct HomeView: View {

    @EnvironmentObject private var authManager: AuthManager
    @Binding var selectedTab: Int

    @State private var searchText = ""
    @State private var showUploadSheet = false
    @ObservedObject private var library = ContentLibrary.shared
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Brand palette

    private let brand = AppTheme.brand
    private let brandDeep = AppTheme.brandDeep
    private let brandSoft = AppTheme.brandSoft
    private let canvas = AppTheme.canvas
    private let ink = AppTheme.ink
    private let muted = AppTheme.muted

    /// Stronger dark green for Home icons and emphasis (readable in bright light).
    private let homeIcon = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.48, green: 0.86, blue: 0.68, alpha: 1)
            : UIColor(red: 0.02, green: 0.22, blue: 0.16, alpha: 1)
    })
    /// Darker secondary copy than the global muted gray.
    private let homeSecondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.82, green: 0.85, blue: 0.84, alpha: 1)
            : UIColor(red: 0.20, green: 0.24, blue: 0.25, alpha: 1)
    })
    /// Icon well — a step deeper than brandSoft so it doesn’t wash out on white.
    private let homeWell = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.20, blue: 0.16, alpha: 1)
            : UIColor(red: 0.80, green: 0.90, blue: 0.85, alpha: 1)
    })
    private let homeStroke = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.22)
            : UIColor(red: 0.06, green: 0.22, blue: 0.17, alpha: 0.12)
    })

    /// Profile tab index: staff have Manage at 3, so Profile is 4.
    private var profileTabIndex: Int {
        authManager.currentUser?.canManageContent == true ? 4 : 3
    }

    private var manageTabIndex: Int { 3 }

    private var isStudent: Bool {
        authManager.currentUser?.isStudent == true
    }

    private var isTutor: Bool {
        authManager.currentUser?.isTutor == true
    }

    /// Form locked at registration / Settings.
    private var studentLevel: Level {
        authManager.currentUser?.studentLevel ?? .form1
    }

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

    private var coreSubjects: [Subject] {
        allSubjects.filter { $0.name != "Optionals" }
    }

    private var optionalsSubject: Subject? {
        allSubjects.first { $0.name == "Optionals" }
    }

    private var dashboardSubjects: [Subject] {
        var list = coreSubjects
        if let optionalsSubject { list.append(optionalsSubject) }
        return list
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
        Group {
            if authManager.currentUser?.isAdmin == true {
                AdminHomeView(showsOverview: true)
            } else if isStudent {
                studentDashboard
            } else if isTutor {
                AdminHomeView(showsOverview: true)
            } else {
                staffHome
            }
        }
        .onAppear {
            StatsManager.shared.recordAppActive()
            TriconAcademyLibrary.preload()
        }
        .sheet(isPresented: $showUploadSheet) {
            UploadLessonView()
                .environmentObject(authManager)
        }
    }

    // MARK: - Student dashboard

    private var firstName: String {
        let name = authManager.currentUser?.fullName ?? "there"
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    private var studentDashboard: some View {
        let hPad: CGFloat = 20

        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                studentHeader
                LiveHomeCard()
                studentSubjectsSection
                studentLibraryRow
                Spacer(minLength: 0)
            }
            .padding(.horizontal, hPad)
            .padding(.top, 18)
            .padding(.bottom, 28)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(
            ZStack {
                canvas.ignoresSafeArea()
                LinearGradient(
                    colors: [
                        brandSoft.opacity(0.38),
                        canvas,
                        canvas
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        )
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var studentHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(greeting)
                    .appFont(size: 14, weight: .medium)
                    .foregroundColor(muted)
                Text(firstName)
                    .appFont(size: 28, weight: .bold, design: .rounded)
                    .foregroundColor(ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 8)
            Button {
                selectedTab = profileTabIndex
            } label: {
                Text(initials)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        LinearGradient(colors: [brand, AppTheme.brandFillDeep],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 19, style: .continuous)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1))
                    .shadow(color: brand.opacity(0.18), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityLabel("Open profile")
        }
    }

    private var studentSubjectsSection: some View {
        let gridGap: CGFloat = 12
        let subjects = dashboardSubjects

        return VStack(alignment: .leading, spacing: 16) {
            subjectHeadingLayout {
                Text("Your subjects")
                    .appFont(size: 21, weight: .bold, design: .rounded)
                    .foregroundColor(ink)
                    .accessibilityAddTraits(.isHeader)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                Text(studentLevel.rawValue)
                    .appFont(size: 12, weight: .semibold)
                    .foregroundColor(homeIcon)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(brandSoft, in: Capsule())
            }

            LazyVGrid(
                columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 145), spacing: gridGap)],
                spacing: gridGap
            ) {
                ForEach(subjects) { subject in
                    NavigationLink {
                        if subject.name == "Optionals" {
                            OptionalsListView(level: studentLevel)
                        } else {
                            ContentHubView(level: studentLevel, subject: subject)
                        }
                    } label: {
                        studentSubjectCard(subject)
                    }
                    .buttonStyle(SoftPressStyle())
                }
            }
        }
    }

    private var subjectHeadingLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
    }

    private func displayName(for subject: Subject) -> String {
        subject.name == "Optionals" ? "Optional Subjects" : subject.name
    }

    private func studentSubjectCard(_ subject: Subject) -> some View {
        let counts = contentCounts(for: subject)
        let isOptionals = subject.name == "Optionals"
        let subtitle = isOptionals
            ? "Civic · Accounts · RE · CS"
            : "\(counts.papers) papers · \(counts.notes) notes · \(counts.videos) videos"

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: subject.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(subject.swiftUIColor)
                    .frame(width: 44, height: 44)
                    .background(subject.swiftUIColor.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(subject.swiftUIColor)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(displayName(for: subject))
                    .appFont(size: 16, weight: .semibold)
                    .foregroundColor(ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .appFont(size: 11.5)
                    .foregroundColor(muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 152, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(colors: [subject.swiftUIColor.opacity(0.06), .clear],
                                             startPoint: .topTrailing, endPoint: .bottomLeading))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(subject.swiftUIColor.opacity(0.15), lineWidth: 1)
                }
                .shadow(color: AppTheme.shadow.opacity(0.45), radius: 10, x: 0, y: 4)
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayName(for: subject)). \(subtitle).")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens lessons for this subject")
    }

    private var homeCardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(AppTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(homeStroke, lineWidth: 1)
            )
    }

    private func contentCounts(for subject: Subject) -> (papers: Int, notes: Int, videos: Int) {
        if subject.name == "Optionals" {
            var p = 0, n = 0, v = 0
            for s in optionalSubjects {
                p += CurriculumData.pastPapers(level: studentLevel, subject: s.name).count
                    + library.papers(level: studentLevel, subject: s.name).count
                n += CurriculumData.materials(level: studentLevel, subject: s.name).count
                    + library.materials(level: studentLevel, subject: s.name).count
                v += CurriculumData.videos(level: studentLevel, subject: s.name).count
                    + library.videos(level: studentLevel, subject: s.name).count
            }
            return (p, n, v)
        }
        let papers = CurriculumData.pastPapers(level: studentLevel, subject: subject.name).count
            + library.papers(level: studentLevel, subject: subject.name).count
        let notes = CurriculumData.materials(level: studentLevel, subject: subject.name).count
            + library.materials(level: studentLevel, subject: subject.name).count
        let videos = CurriculumData.videos(level: studentLevel, subject: subject.name).count
            + library.videos(level: studentLevel, subject: subject.name).count
        return (papers, notes, videos)
    }

    private var studentLibraryRow: some View {
        NavigationLink {
            TriconAcademyLibraryView()
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(homeIcon)
                    .symbolRenderingMode(.monochrome)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous)
                            .fill(homeWell)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Tricon Academy Library")
                        .appFont(size: 15, weight: .semibold)
                        .foregroundColor(ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Extra reading beyond the syllabus")
                        .appFont(size: 12.5, weight: .regular)
                        .foregroundColor(homeSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(homeSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(homeCardBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel("Tricon Academy Library. Extra reading beyond your syllabus.")
        .accessibilityHint("Opens books and extra reading")
    }

    // MARK: - Staff home (admin — all forms)

    private var staffHome: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {

                header
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.top, 4)

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
            .padding(.bottom, 20)
        }
        .background(canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header (staff)

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .appFont(size: 14, weight: .medium)
                    .foregroundColor(muted)
                Text(authManager.currentUser?.fullName ?? "Student")
                    .appFont(size: 24, weight: .bold, design: .rounded)
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
                                colors: [AppTheme.brand, AppTheme.brandFillDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: brand.opacity(0.28), radius: 10, x: 0, y: 5)

                    Text(initials)
                        .appFont(size: 15, weight: .bold)
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityLabel("Open profile")
        }
    }

    private var staffActions: some View {
        HStack(spacing: 8) {
            Button {
                showUploadSheet = true
            } label: {
                Label("Upload", systemImage: "arrow.up.doc.fill")
                    .font(.system(size: 12.5, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.brand, AppTheme.brandFillDeep],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous))
                    .shadow(color: brand.opacity(0.18), radius: 6, x: 0, y: 3)
            }

            Button {
                selectedTab = manageTabIndex
            } label: {
                Label("Manage", systemImage: "slider.horizontal.3")
                    .font(.system(size: 12.5, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(brandSoft)
                    .foregroundColor(brandDeep)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous)
                            .stroke(brand.opacity(0.16), lineWidth: 1)
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
                    AppIconLabel(systemName: "xmark", tint: AppTheme.secondaryInk, fill: AppTheme.fill)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow, radius: 6, x: 0, y: 2)
    }

    // MARK: - Grades (staff)

    private var gradesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            LevelPickerHeader(
                title: "Curriculum forms",
                subtitle: "Select a form to open subjects, papers, notes, and videos."
            )
            .padding(.horizontal, AppTheme.horizontalPadding)

            LevelPickerGrid { level in
                SubjectListView(level: level)
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
        }
    }

    // MARK: - Tricon Academy Library (staff)

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tricon Academy Library")
                .appFont(size: 16, weight: .bold)
                .foregroundColor(ink)
                .padding(.horizontal, AppTheme.horizontalPadding)

            NavigationLink {
                TriconAcademyLibraryView()
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                            .fill(brandSoft)
                            .frame(width: 52, height: 52)
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(brandDeep)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Browse the library")
                            .appFont(size: 16, weight: .semibold)
                            .foregroundColor(ink)
                        Text("Tech · Science · Business · Stories")
                            .appFont(size: 12.5, weight: .medium)
                            .foregroundColor(muted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.subtle)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                        .fill(AppTheme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                        .stroke(brand.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 3)
            }
            .buttonStyle(SoftPressStyle())
            .padding(.horizontal, AppTheme.horizontalPadding)
        }
        .padding(.top, 2)
    }

    // MARK: - Quick access (staff)

    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick access")
                .appFont(size: 16, weight: .bold)
                .foregroundColor(ink)
                .padding(.horizontal, AppTheme.horizontalPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    quickChip(
                        icon: "doc.text.fill",
                        title: "Papers",
                        color: AppTheme.papers,
                        soft: AppTheme.papersSoft,
                        destination: BrowseLevelsView(
                            title: "Papers",
                            subtitle: "Choose a level to browse past papers.",
                            targetTab: 0
                        )
                    )
                    quickChip(
                        icon: "note.text",
                        title: "Notes",
                        color: AppTheme.notes,
                        soft: AppTheme.notesSoft,
                        destination: BrowseLevelsView(
                            title: "Notes",
                            subtitle: "Choose a level to browse notes.",
                            targetTab: 1
                        )
                    )
                    quickChip(
                        icon: "play.rectangle.fill",
                        title: "Videos",
                        color: AppTheme.videos,
                        soft: AppTheme.videosSoft,
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
                            Image(systemName: "video.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Live Lessons")
                                .appFont(size: 13, weight: .semibold)
                        }
                        .foregroundColor(AppTheme.brandBright)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(AppTheme.brandBright.opacity(0.14))
                        )
                    }
                    .buttonStyle(SoftPressStyle())
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
        soft: Color,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .appFont(size: 13, weight: .semibold)
            }
            .foregroundColor(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Capsule().fill(soft))
            .overlay(Capsule().stroke(color.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle())
    }

    // MARK: - Search results (staff)

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
                        .appFont(size: 15, weight: .semibold)
                        .foregroundColor(ink)
                    Text("Try a subject like Physics, or a level like Form 1.")
                        .appFont(size: 13)
                        .foregroundColor(muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
                .padding(.horizontal, AppTheme.horizontalPadding)
            } else {
                if !filteredLevels.isEmpty {
                    Text("Levels")
                        .appFont(size: 17, weight: .bold)
                        .foregroundColor(ink)
                        .padding(.horizontal, AppTheme.horizontalPadding)

                    VStack(spacing: 12) {
                        ForEach(filteredLevels) { level in
                            NavigationLink(destination: SubjectListView(level: level)) {
                                LevelTile(level: level, style: .row)
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                }

                if !filteredSubjects.isEmpty {
                    Text("Subjects")
                        .appFont(size: 17, weight: .bold)
                        .foregroundColor(ink)
                        .padding(.horizontal, AppTheme.horizontalPadding)

                    VStack(spacing: 10) {
                        ForEach(filteredSubjects) { subject in
                            NavigationLink(destination: SubjectLevelPickerView(subject: subject)) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                                            .fill(subject.swiftUIColor.opacity(0.14))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: subject.icon)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(subject.swiftUIColor)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(subject.name)
                                            .appFont(size: 15, weight: .semibold)
                                            .foregroundColor(ink)
                                        Text("Choose a level to open")
                                            .appFont(size: 12)
                                            .foregroundColor(muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(AppTheme.subtle)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                                        .fill(AppTheme.card)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                                        .stroke(AppTheme.stroke, lineWidth: 1)
                                )
                            }
                            .buttonStyle(SoftPressStyle())
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
