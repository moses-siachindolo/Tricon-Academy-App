import SwiftUI

/// Browse past papers by form (Form 1–4).
struct PapersLibraryView: View {

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                LevelPickerHeader(
                    title: "Past papers",
                    subtitle: "Choose a form to open past papers for every subject."
                )
                .padding(.horizontal, AppTheme.horizontalPadding)

                LevelPickerGrid(
                    subtitle: { _ in "Past papers" }
                ) { level in
                    SubjectListView(level: level, initialTab: 0)
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
            }
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("Papers")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PapersLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PapersLibraryView()
        }
    }
}
