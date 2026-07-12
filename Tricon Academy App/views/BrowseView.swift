import SwiftUI

/// Primary Browse tab: pick a level, then a subject, then content.
struct BrowseView: View {

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Browse curriculum")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Choose your level, then pick a subject for papers, notes and videos.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 22)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Level.allCases) { level in
                        NavigationLink(destination: SubjectListView(level: level)) {
                            VStack(spacing: 10) {
                                Image(systemName: level.icon)
                                    .font(.system(size: 30))
                                    .foregroundColor(.green)
                                Text(level.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text("\(allSubjects.count) subjects")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 110)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)
            }
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("Browse")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// After a search hit on a subject, let the user pick which level to open.
struct SubjectLevelPickerView: View {

    let subject: Subject
    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Which level for \(subject.name)?")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 22)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Level.allCases) { level in
                        NavigationLink(destination: destination(for: level)) {
                            VStack(spacing: 10) {
                                Image(systemName: level.icon)
                                    .font(.system(size: 30))
                                    .foregroundColor(.green)
                                Text(level.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)
            }
            .padding(.top, 16)
        }
        .navigationTitle(subject.name)
        .navigationBarTitleDisplayMode(.inline)
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
    }
}
