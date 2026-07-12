import SwiftUI

struct OptionalsListView: View {

    let level: Level

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    private let horizontalPadding: CGFloat = 22
    private let gridSpacing: CGFloat = 16

    private var pairedSubjects: [Subject] {
        optionalSubjects.count % 2 == 0 ? optionalSubjects : Array(optionalSubjects.dropLast())
    }

    private var leftoverSubject: Subject? {
        optionalSubjects.count % 2 == 0 ? nil : optionalSubjects.last
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Optional Subjects")
                            .font(.title3)
                            .fontWeight(.bold)

                        Text("Pick an optional subject to explore past papers, notes and videos.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 28)

                    LazyVGrid(columns: columns, spacing: gridSpacing) {
                        ForEach(pairedSubjects) { subject in
                            NavigationLink(destination: ContentHubView(level: level, subject: subject)) {
                                SubjectCardView(subject: subject)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, horizontalPadding)

                    if let leftover = leftoverSubject {
                        let cardWidth = (geo.size.width - (horizontalPadding * 2) - gridSpacing) / 2

                        HStack {
                            Spacer()
                            NavigationLink(destination: ContentHubView(level: level, subject: leftover)) {
                                SubjectCardView(subject: leftover)
                                    .frame(width: cardWidth)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        .padding(.horizontal, horizontalPadding)
                    }

                    Spacer(minLength: 30)
                }
                .frame(minHeight: geo.size.height, alignment: .top)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Optionals")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct OptionalsListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            OptionalsListView(level: .form1)
        }
    }
}
