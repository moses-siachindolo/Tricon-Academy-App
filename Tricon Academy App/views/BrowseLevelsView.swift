import SwiftUI

/// Level-picker used by the Home screen's Quick Access shortcuts
/// (Papers / Videos / Notes) to jump straight into browsing with the right
/// content tab pre-selected once a subject is chosen.
struct BrowseLevelsView: View {

    let title: String
    let subtitle: String
    let targetTab: Int

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                LevelPickerHeader(title: title, subtitle: subtitle)
                    .padding(.horizontal, AppTheme.horizontalPadding)

                LevelPickerGrid(
                    subtitle: { _ in contentLabel }
                ) { level in
                    SubjectListView(level: level, initialTab: targetTab)
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
            }
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .appScreen()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var contentLabel: String {
        switch targetTab {
        case 0: return "Past papers"
        case 1: return "Study notes"
        case 2: return "Video lessons"
        default: return "Browse content"
        }
    }
}

struct BrowseLevelsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BrowseLevelsView(title: "Papers", subtitle: "Choose a level to browse past papers.", targetTab: 0)
        }
    }
}
