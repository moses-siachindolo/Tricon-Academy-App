import SwiftUI

/// Primary Browse tab: pick a level, then a subject, then content.
struct BrowseView: View {

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                LevelPickerHeader(
                    title: "Browse curriculum",
                    subtitle: "Choose your form (Form 1–4), then open a subject for papers, notes, and videos."
                )
                .padding(.horizontal, AppTheme.horizontalPadding)

                LevelPickerGrid { level in
                    SubjectListView(level: level)
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
            }
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("Browse")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// After a search hit on a subject, let the user pick which level to open.
struct SubjectLevelPickerView: View {

    let subject: Subject

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                LevelPickerHeader(
                    title: "Choose a level",
                    subtitle: "Which form for \(subject.name)? Choose Form 1–4."
                )
                .padding(.horizontal, AppTheme.horizontalPadding)

                LevelPickerGrid(
                    subtitle: { _ in "Open \(subject.name)" },
                    accent: { _ in subject.swiftUIColor }
                ) { level in
                    destination(for: level)
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
            }
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
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
