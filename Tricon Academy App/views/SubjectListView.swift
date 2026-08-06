import SwiftUI

struct SubjectListView: View {

    let level: Level
    var initialTab: Int = 0

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    /// Core subjects excluding the Optionals folder entry (handled separately).
    private var coreSubjects: [Subject] {
        allSubjects.filter { $0.name != "Optionals" }
    }

    private var optionalsSubject: Subject? {
        allSubjects.first { $0.name == "Optionals" }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subjects")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.ink)
                    Text("Pick a subject for \(level.rawValue) — papers, notes, and video lessons.")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.muted)
                }
                .padding(.horizontal, AppTheme.horizontalPadding)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(coreSubjects) { subject in
                        NavigationLink(destination: ContentHubView(level: level, subject: subject, initialTab: initialTab)) {
                            SubjectCardView(subject: subject)
                        }
                        .buttonStyle(.plain)
                    }

                    if let optionalsSubject {
                        NavigationLink(destination: OptionalsListView(level: level, initialTab: initialTab)) {
                            SubjectCardView(subject: optionalsSubject)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
            }
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle(level.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SubjectListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SubjectListView(level: .form4)
        }
    }
}
