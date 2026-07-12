import SwiftUI

/// Level-picker used by the Home screen's Quick Access shortcuts
/// (Papers / Videos / Notes) to jump straight into browsing with the right
/// content tab pre-selected once a subject is chosen.
struct BrowseLevelsView: View {

    let title: String
    let subtitle: String
    let targetTab: Int

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 22)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Level.allCases) { level in
                        NavigationLink(destination: SubjectListView(level: level, initialTab: targetTab)) {
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
                    }
                }
                .padding(.horizontal, 22)
            }
            .padding(.top, 16)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BrowseLevelsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BrowseLevelsView(title: "Papers", subtitle: "Choose a level to browse past papers.", targetTab: 0)
        }
    }
}
