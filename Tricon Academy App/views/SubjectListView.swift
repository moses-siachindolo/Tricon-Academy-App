import SwiftUI

/// Subject grid for a form — uniform brand green, screen-fit cards (matches student Home).
/// Tutors see specialist majors only; students/admins see the full grid.
@MainActor
struct SubjectListView: View {

    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject private var library = ContentLibrary.shared
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var searchText = ""

    let level: Level
    var initialTab: Int = 0
    /// When true, ignore tutor major filter (used from Settings “other subjects”).
    var showAllSubjects: Bool = false

    private let brand = AppTheme.brand
    private let brandDeep = AppTheme.brandDeep
    private let brandSoft = AppTheme.brandSoft
    private let canvas = AppTheme.canvas
    private let ink = AppTheme.ink
    private let iconGreen = AppTheme.iconGreen
    private let secondary = AppTheme.secondaryInk
    private let well = AppTheme.iconWell
    private let cardLine = AppTheme.cardLine

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
            return majors
        }
        var list = coreSubjects
        if let optionalsSubject { list.append(optionalsSubject) }
        return list
    }

    private var filteredSubjects: [Subject] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? subjects : subjects.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                Text("Subjects")
                    .appFont(size: 13, weight: .bold)
                    .foregroundColor(iconGreen)
                    .tracking(0.6)
                    .textCase(.uppercase)

                if subjects.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(iconGreen)
                            .symbolRenderingMode(.monochrome)
                        Text("No specialist subjects")
                            .font(.headline)
                            .foregroundColor(ink)
                        Text("Set your majors in Settings to browse them by form.")
                            .appFont(size: 13, weight: .medium)
                            .foregroundColor(secondary)
                            .multilineTextAlignment(.center)
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Text("Open Settings")
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredSubjects.isEmpty {
                    AppEmptyState(icon: "magnifyingglass", title: "No subjects found", message: "Try a different subject name.")
                    Button("Clear search") { searchText = "" }
                        .buttonStyle(AppSecondaryButtonStyle())
                } else {
                    LazyVGrid(
                        columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 145), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(filteredSubjects) { subject in
                            NavigationLink {
                                if subject.name == "Optionals" {
                                    OptionalsListView(level: level, initialTab: initialTab)
                                } else {
                                    ContentHubView(level: level, subject: subject, initialTab: initialTab)
                                }
                            } label: {
                                subjectCard(subject)
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 14)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .searchable(text: $searchText, prompt: "Find a subject")
        .background(brandWash)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(level.rawValue)
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

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.brand, AppTheme.brandFillDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)

                Text(level.shortLabel)
                    .appFont(size: 16, weight: .bold, design: .rounded)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(authManager.currentUser?.isAdmin == true
                     ? "Subject catalogue"
                     : (authManager.currentUser?.isTutor == true && !showAllSubjects
                        ? "Teaching subjects" : "Browse subjects"))
                    .appFont(size: 22, weight: .bold)
                    .foregroundColor(ink)
                    .lineLimit(2)

                Text(authManager.currentUser?.isAdmin == true
                     ? "Manage papers, notes and lessons for \(level.rawValue)"
                     : (authManager.currentUser?.isTutor == true && !showAllSubjects
                        ? "Specialist courses for \(level.rawValue)"
                        : "Papers, notes & videos for \(level.rawValue)"))
                    .appFont(size: 13.5, weight: .medium)
                    .foregroundColor(secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
    }

    private func subjectCard(_ subject: Subject) -> some View {
        let counts = contentCounts(for: subject)
        let isOptionals = subject.name == "Optionals"
        let title = isOptionals ? "Optional Subjects" : subject.name
        let subtitle = isOptionals
            ? "Civic · Accounts · RE · CS"
            : "\(counts.papers) papers · \(counts.notes) notes · \(counts.videos) videos"

        return VStack(alignment: .leading, spacing: 8) {
            Image(systemName: subject.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconGreen)
                .symbolRenderingMode(.monochrome)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous)
                        .fill(well)
                )
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
                .foregroundColor(ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
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
        .accessibilityLabel("\(title). \(subtitle).")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens lessons for this subject")
    }

    private func contentCounts(for subject: Subject) -> (papers: Int, notes: Int, videos: Int) {
        if subject.name == "Optionals" {
            var p = 0, n = 0, v = 0
            for s in optionalSubjects {
                p += CurriculumData.pastPapers(level: level, subject: s.name).count
                    + library.papers(level: level, subject: s.name).count
                n += CurriculumData.materials(level: level, subject: s.name).count
                    + library.materials(level: level, subject: s.name).count
                v += CurriculumData.videos(level: level, subject: s.name).count
                    + library.videos(level: level, subject: s.name).count
            }
            return (p, n, v)
        }
        let papers = CurriculumData.pastPapers(level: level, subject: subject.name).count
            + library.papers(level: level, subject: subject.name).count
        let notes = CurriculumData.materials(level: level, subject: subject.name).count
            + library.materials(level: level, subject: subject.name).count
        let videos = CurriculumData.videos(level: level, subject: subject.name).count
            + library.videos(level: level, subject: subject.name).count
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
