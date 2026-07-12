import SwiftUI

struct SubjectListView: View {

    let level: Level
    var initialTab: Int = 0

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    private let horizontalPadding: CGFloat = 22
    private let gridSpacing: CGFloat = 16

    /// Core subjects excluding the Optionals folder entry (handled separately).
    private var coreSubjects: [Subject] {
        allSubjects.filter { $0.name != "Optionals" }
    }

    private var optionalsSubject: Subject? {
        allSubjects.first { $0.name == "Optionals" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Pick a subject for \(level.rawValue).")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.horizontal, horizontalPadding)

                LazyVGrid(columns: columns, spacing: gridSpacing) {
                    ForEach(coreSubjects) { subject in
                        NavigationLink(destination: ContentHubView(level: level, subject: subject, initialTab: initialTab)) {
                            SubjectCardView(subject: subject)
                        }
                        .buttonStyle(.plain)
                    }

                    if let optionalsSubject {
                        NavigationLink(destination: OptionalsListView(level: level)) {
                            SubjectCardView(subject: optionalsSubject)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, horizontalPadding)
            }
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(level.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SubjectListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SubjectListView(level: .form1)
        }
    }
}
