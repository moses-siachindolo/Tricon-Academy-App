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

    /// Specialist subjects for the tutor home grid (majors + approved extras).
    private var tutorMajorSubjects: [Subject] {
        authManager.currentUser?.managedSubjects ?? []
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
            if isStudent {
                studentDashboard
            } else if isTutor {
                tutorDashboard
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

    // MARK: - Student dashboard (uniform brand, screen-fit)

    private var firstName: String {
        let name = authManager.currentUser?.fullName ?? "there"
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    private var studentDashboard: some View {
        GeometryReader { geo in
            let hPad: CGFloat = 16
            let gridGap: CGFloat = 8
            let headerH: CGFloat = 52
            let sectionGap: CGFloat = 10
            let libraryH: CGFloat = 54
            let topPad: CGFloat = 6
            let bottomPad: CGFloat = 8
            let subjects = dashboardSubjects
            let rows = max(1, Int(ceil(Double(subjects.count) / 2.0)))
            let usedFixed = topPad + headerH + sectionGap + 20 + sectionGap + libraryH + bottomPad
            let gridAvailable = max(240, geo.size.height - usedFixed)
            let cardH = max(92, (gridAvailable - CGFloat(rows - 1) * gridGap) / CGFloat(rows))

            VStack(alignment: .leading, spacing: sectionGap) {
                studentHeader
                    .frame(height: headerH, alignment: .center)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Subjects")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(brandDeep)
                        .tracking(0.5)
                        .textCase(.uppercase)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: gridGap),
                            GridItem(.flexible(), spacing: gridGap)
                        ],
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
                                studentSubjectCard(subject, height: cardH)
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)

                studentLibraryRow
                    .frame(height: libraryH)
            }
            .padding(.horizontal, hPad)
            .padding(.top, topPad)
            .padding(.bottom, bottomPad)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .background(
            ZStack {
                canvas.ignoresSafeArea()
                // Soft brand wash — uniform green atmosphere
                LinearGradient(
                    colors: [
                        brandSoft.opacity(0.48),
                        canvas,
                        canvas
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        )
        .navigationBarHidden(true)
    }

    private var studentHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            // Brand form badge
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [brand, brandDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: brand.opacity(0.22), radius: 6, x: 0, y: 3)

                Text(studentLevel.shortLabel)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(studentLevel.rawValue)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ink)
                    .lineLimit(1)

                Text("Hi \(firstName) — ready to learn?")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Button {
                selectedTab = profileTabIndex
            } label: {
                ZStack {
                    Circle()
                        .fill(brandSoft)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Circle()
                                .stroke(brand.opacity(0.16), lineWidth: 1)
                        )
                    Text(initials)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(brandDeep)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open profile")
        }
    }

    private func studentSubjectCard(_ subject: Subject, height: CGFloat) -> some View {
        let counts = contentCounts(for: subject)
        let total = counts.papers + counts.notes + counts.videos

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: subject.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(brandDeep)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(brandSoft)
                    )

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(brand.opacity(0.4))
                    .padding(5)
                    .background(Circle().fill(brandSoft.opacity(0.7)))
            }

            Spacer(minLength: 6)

            Text(subject.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text("\(total) resources")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(muted)
                .padding(.top, 2)

            HStack(spacing: 4) {
                metaDot("\(counts.papers)P")
                metaDot("\(counts.notes)N")
                metaDot("\(counts.videos)V")
            }
            .padding(.top, 6)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(brand.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: brand.opacity(0.04), radius: 8, x: 0, y: 3)
        .shadow(color: Color.black.opacity(0.02), radius: 1, x: 0, y: 1)
    }

    private func metaDot(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .bold, design: .rounded))
            .foregroundColor(brandDeep)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(brandSoft)
            )
    }

    private func contentCounts(for subject: Subject) -> (papers: Int, notes: Int, videos: Int) {
        if subject.name == "Optionals" {
            var p = 0, n = 0, v = 0
            for s in optionalSubjects {
                p += CurriculumData.pastPapers(level: studentLevel, subject: s.name).count
                    + ContentLibrary.shared.papers(level: studentLevel, subject: s.name).count
                n += CurriculumData.materials(level: studentLevel, subject: s.name).count
                    + ContentLibrary.shared.materials(level: studentLevel, subject: s.name).count
                v += CurriculumData.videos(level: studentLevel, subject: s.name).count
                    + ContentLibrary.shared.videos(level: studentLevel, subject: s.name).count
            }
            return (p, n, v)
        }
        let papers = CurriculumData.pastPapers(level: studentLevel, subject: subject.name).count
            + ContentLibrary.shared.papers(level: studentLevel, subject: subject.name).count
        let notes = CurriculumData.materials(level: studentLevel, subject: subject.name).count
            + ContentLibrary.shared.materials(level: studentLevel, subject: subject.name).count
        let videos = CurriculumData.videos(level: studentLevel, subject: subject.name).count
            + ContentLibrary.shared.videos(level: studentLevel, subject: subject.name).count
        return (papers, notes, videos)
    }

    private var studentLibraryRow: some View {
        NavigationLink {
            TriconAcademyLibraryView()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [brand, brandDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text("Tricon Academy Library")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(ink)
                        .lineLimit(1)
                    Text("Books & extra reading")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(brandDeep)
                    .padding(6)
                    .background(Circle().fill(brandSoft))
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(brand.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: brand.opacity(0.04), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(SoftPressStyle())
    }

    // MARK: - Tutor dashboard (compact, majors only, admin-locked)

    private var tutorDashboard: some View {
        GeometryReader { geo in
            let hPad: CGFloat = 16
            let gridGap: CGFloat = 6
            let headerH: CGFloat = 48
            let sectionGap: CGFloat = 8
            let showActions = authManager.currentUser?.canManageContent == true
            let actionsH: CGFloat = showActions ? 30 : 0
            let libraryH: CGFloat = 50
            let topPad: CGFloat = 4
            let bottomPad: CGFloat = 6
            let subjects = tutorMajorSubjects
            let rows = max(1, Int(ceil(Double(max(subjects.count, 1)) / 2.0)))
            let actionsBlock = showActions ? (actionsH + sectionGap) : 0
            let usedFixed = topPad + headerH + sectionGap + actionsBlock + 18 + sectionGap + libraryH + bottomPad
            let gridAvailable = max(200, geo.size.height - usedFixed)
            let cardH = max(84, min(110, (gridAvailable - CGFloat(rows - 1) * gridGap) / CGFloat(rows)))

            VStack(alignment: .leading, spacing: sectionGap) {
                tutorHeader
                    .frame(height: headerH, alignment: .center)

                if showActions {
                    tutorActions
                        .frame(height: actionsH)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Text("Your subjects")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(brandDeep)
                            .tracking(0.4)
                            .textCase(.uppercase)

                        Image(systemName: "lock.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(brand.opacity(0.55))

                        Spacer(minLength: 4)

                        NavigationLink {
                            SettingsView()
                        } label: {
                            Text("Request access")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(brandDeep)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(brandSoft))
                        }
                        .buttonStyle(.plain)
                    }

                    if subjects.isEmpty {
                        tutorEmptyMajorsCard
                            .frame(maxWidth: .infinity, minHeight: max(120, gridAvailable * 0.5))
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: gridGap),
                                GridItem(.flexible(), spacing: gridGap)
                            ],
                            spacing: gridGap
                        ) {
                            ForEach(subjects) { subject in
                                NavigationLink {
                                    SubjectLevelPickerView(subject: subject)
                                } label: {
                                    tutorSubjectCard(subject, height: cardH)
                                }
                                .buttonStyle(SoftPressStyle())
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)

                tutorLibraryRow
                    .frame(height: libraryH)
            }
            .padding(.horizontal, hPad)
            .padding(.top, topPad)
            .padding(.bottom, bottomPad)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .background(
            ZStack {
                canvas.ignoresSafeArea()
                LinearGradient(
                    colors: [
                        brandSoft.opacity(0.45),
                        canvas,
                        canvas
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        )
        .navigationBarHidden(true)
    }

    private var tutorHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [brand, brandDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: brand.opacity(0.2), radius: 6, x: 0, y: 3)

                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Tutor")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(ink)
                    .lineLimit(1)

                Text(tutorMajorSubjects.isEmpty
                     ? "Hi \(firstName) · majors pending"
                     : "Hi \(firstName) · \(tutorMajorSubjects.count) approved")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Button {
                selectedTab = profileTabIndex
            } label: {
                ZStack {
                    Circle()
                        .fill(brandSoft)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Circle()
                                .stroke(brand.opacity(0.16), lineWidth: 1)
                        )
                    Text(initials)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(brandDeep)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open profile")
        }
    }

    private var tutorActions: some View {
        HStack(spacing: 6) {
            Button {
                showUploadSheet = true
            } label: {
                Label("Upload", systemImage: "arrow.up.doc.fill")
                    .font(.system(size: 11.5, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(
                        LinearGradient(
                            colors: [brand, brandDeep],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Button {
                selectedTab = manageTabIndex
            } label: {
                Label("Manage", systemImage: "slider.horizontal.3")
                    .font(.system(size: 11.5, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(brandSoft)
                    .foregroundColor(brandDeep)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(brand.opacity(0.16), lineWidth: 1)
                    )
            }
        }
    }

    private var tutorEmptyMajorsCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.rectangle.stack")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(brandDeep)
                .padding(10)
                .background(Circle().fill(brandSoft))

            Text("No approved subjects")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(ink)

            Text("Majors are set during verification. Request extra subjects in Settings — an admin must approve.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)

            NavigationLink {
                SettingsView()
            } label: {
                Text("Open Settings")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [brand, brandDeep], startPoint: .leading, endPoint: .trailing)
                        )
                    )
            }
            .buttonStyle(SoftPressStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(brand.opacity(0.10), lineWidth: 1)
        )
    }

    private func tutorSubjectCard(_ subject: Subject, height: CGFloat) -> some View {
        let counts = tutorContentCounts(for: subject)
        let total = counts.papers + counts.notes + counts.videos
        let canManage = authManager.currentUser?.canManageSubject(subject.name) == true

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: subject.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(brandDeep)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(brandSoft)
                    )

                Spacer(minLength: 4)

                if canManage {
                    Text("Edit")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(brandDeep)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(brandSoft))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(brand.opacity(0.4))
            }

            Spacer(minLength: 6)

            Text(subject.name)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundColor(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text("\(total) resources")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(muted)
                .padding(.top, 2)

            HStack(spacing: 4) {
                tutorMeta("\(counts.papers)P")
                tutorMeta("\(counts.notes)N")
                tutorMeta("\(counts.videos)V")
            }
            .padding(.top, 6)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(brand.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: brand.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private func tutorMeta(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .bold, design: .rounded))
            .foregroundColor(brandDeep)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(brandSoft))
    }

    private var tutorLibraryRow: some View {
        NavigationLink {
            TriconAcademyLibraryView()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [brand, brandDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text("Academy Library")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(ink)
                        .lineLimit(1)
                    Text("Books & reading")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(brandDeep)
                    .padding(6)
                    .background(Circle().fill(brandSoft))
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(brand.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(SoftPressStyle())
    }

    /// Aggregate resource counts across Form 1–4 for a tutor subject card.
    private func tutorContentCounts(for subject: Subject) -> (papers: Int, notes: Int, videos: Int) {
        var p = 0, n = 0, v = 0
        for level in Level.activeCases {
            p += CurriculumData.pastPapers(level: level, subject: subject.name).count
                + ContentLibrary.shared.papers(level: level, subject: subject.name).count
            n += CurriculumData.materials(level: level, subject: subject.name).count
                + ContentLibrary.shared.materials(level: level, subject: subject.name).count
            v += CurriculumData.videos(level: level, subject: subject.name).count
                + ContentLibrary.shared.videos(level: level, subject: subject.name).count
        }
        return (p, n, v)
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
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header (staff)

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
        HStack(spacing: 8) {
            Button {
                showUploadSheet = true
            } label: {
                Label("Upload", systemImage: "arrow.up.doc.fill")
                    .font(.system(size: 12.5, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        LinearGradient(
                            colors: [brand, brandDeep],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: brand.opacity(0.18), radius: 6, x: 0, y: 3)
            }

            Button {
                selectedTab = manageTabIndex
            } label: {
                Label("Manage", systemImage: "slider.horizontal.3")
                    .font(.system(size: 12.5, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(brandSoft)
                    .foregroundColor(brandDeep)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
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
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.subtle)
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
        .shadow(color: AppTheme.shadow, radius: 6, x: 0, y: 2)
    }

    // MARK: - Grades (staff)

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

    // MARK: - Tricon Academy Library (staff)

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tricon Academy Library")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ink)
                .padding(.horizontal, AppTheme.horizontalPadding)

            NavigationLink {
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
                        .foregroundColor(AppTheme.subtle)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(brand.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppTheme.horizontalPadding)
        }
        .padding(.top, 2)
    }

    // MARK: - Quick access (staff)

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
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Saved")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.bookmark)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(AppTheme.bookmark.opacity(0.14))
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
        soft: Color,
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
            .background(Capsule().fill(soft))
            .overlay(Capsule().stroke(color.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
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
                                        .foregroundColor(AppTheme.subtle)
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
