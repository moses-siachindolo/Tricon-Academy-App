import SwiftUI

/// Subject grid for a form — uniform brand green, screen-fit cards (matches student Home).
/// Tutors see specialist majors only; students/admins see the full grid.
@MainActor
struct SubjectListView: View {

    @EnvironmentObject private var authManager: AuthManager

    let level: Level
    var initialTab: Int = 0
    /// When true, ignore tutor major filter (used from Settings “other subjects”).
    var showAllSubjects: Bool = false

    private let brand = AppTheme.brand
    private let brandDeep = AppTheme.brandDeep
    private let brandSoft = AppTheme.brandSoft
    private let canvas = AppTheme.canvas
    private let ink = AppTheme.ink
    private let muted = AppTheme.muted

    private var coreSubjects: [Subject] {
        allSubjects.filter { $0.name != "Optionals" }
    }

    private var optionalsSubject: Subject? {
        allSubjects.first { $0.name == "Optionals" }
    }

    private var subjects: [Subject] {
        // Tutors: dashboard / browse stay on specialist majors only.
        if !showAllSubjects, authManager.currentUser?.isTutor == true {
            let majors = authManager.currentUser?.managedSubjects ?? []
            if !majors.isEmpty { return majors }
        }
        var list = coreSubjects
        if let optionalsSubject { list.append(optionalsSubject) }
        return list
    }

    var body: some View {
        GeometryReader { geo in
            let hPad: CGFloat = 20
            let gridGap: CGFloat = 12
            let headerH: CGFloat = 78
            let sectionLabelH: CGFloat = 28
            let topPad: CGFloat = 8
            let bottomPad: CGFloat = 16
            let rows = max(1, Int(ceil(Double(subjects.count) / 2.0)))
            let usedFixed = topPad + headerH + sectionLabelH + bottomPad
            let gridAvailable = max(260, geo.size.height - usedFixed)
            let cardH = max(112, (gridAvailable - CGFloat(rows - 1) * gridGap) / CGFloat(rows))

            VStack(alignment: .leading, spacing: 14) {
                header
                    .frame(height: headerH, alignment: .center)

                Text("Subjects")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(brandDeep)
                    .tracking(0.6)
                    .textCase(.uppercase)

                if subjects.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(brandDeep)
                        Text("No specialist subjects")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(ink)
                        Text("Set your majors in Settings to browse them by form.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(muted)
                            .multilineTextAlignment(.center)
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Text("Open Settings")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(
                                    LinearGradient(colors: [brand, brandDeep], startPoint: .leading, endPoint: .trailing)
                                ))
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                                if subject.name == "Optionals" {
                                    OptionalsListView(level: level, initialTab: initialTab)
                                } else {
                                    ContentHubView(level: level, subject: subject, initialTab: initialTab)
                                }
                            } label: {
                                subjectCard(subject, height: cardH)
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }

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
                Text(level.rawValue)
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

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [brand, brandDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: brand.opacity(0.28), radius: 12, x: 0, y: 6)

                Text(level.shortLabel)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(authManager.currentUser?.isTutor == true && !showAllSubjects
                     ? "Your subjects"
                     : "Browse subjects")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(ink)
                    .lineLimit(1)

                Text(authManager.currentUser?.isTutor == true && !showAllSubjects
                     ? "Specialist courses for \(level.rawValue)"
                     : "Papers, notes & videos for \(level.rawValue)")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private func subjectCard(_ subject: Subject, height: CGFloat) -> some View {
        let counts = contentCounts(for: subject)
        let total = counts.papers + counts.notes + counts.videos

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(brandSoft)
                        .frame(width: 44, height: 44)
                    Image(systemName: subject.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(brandDeep)
                        .symbolRenderingMode(.hierarchical)
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(brand.opacity(0.45))
                    .padding(7)
                    .background(Circle().fill(brandSoft.opacity(0.7)))
            }

            Spacer(minLength: 10)

            Text(subject.name)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.9)

            Text("\(total) resources")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(muted)
                .padding(.top, 3)

            HStack(spacing: 6) {
                metaDot("\(counts.papers)P")
                metaDot("\(counts.notes)N")
                metaDot("\(counts.videos)V")
            }
            .padding(.top, 10)
        }
        .padding(14)
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

    private func metaDot(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold, design: .rounded))
            .foregroundColor(brandDeep)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Capsule().fill(brandSoft))
    }

    private func contentCounts(for subject: Subject) -> (papers: Int, notes: Int, videos: Int) {
        if subject.name == "Optionals" {
            var p = 0, n = 0, v = 0
            for s in optionalSubjects {
                p += CurriculumData.pastPapers(level: level, subject: s.name).count
                    + ContentLibrary.shared.papers(level: level, subject: s.name).count
                n += CurriculumData.materials(level: level, subject: s.name).count
                    + ContentLibrary.shared.materials(level: level, subject: s.name).count
                v += CurriculumData.videos(level: level, subject: s.name).count
                    + ContentLibrary.shared.videos(level: level, subject: s.name).count
            }
            return (p, n, v)
        }
        let papers = CurriculumData.pastPapers(level: level, subject: subject.name).count
            + ContentLibrary.shared.papers(level: level, subject: subject.name).count
        let notes = CurriculumData.materials(level: level, subject: subject.name).count
            + ContentLibrary.shared.materials(level: level, subject: subject.name).count
        let videos = CurriculumData.videos(level: level, subject: subject.name).count
            + ContentLibrary.shared.videos(level: level, subject: subject.name).count
        return (papers, notes, videos)
    }
}

struct SubjectListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SubjectListView(level: .form3)
        }
        .environmentObject(AuthManager.shared)
    }
}
