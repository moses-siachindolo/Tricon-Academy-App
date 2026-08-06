import SwiftUI

struct OptionalsListView: View {

    let level: Level
    var initialTab: Int = 0

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Optional subjects")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.ink)
                    Text("Optional subjects for \(level.rawValue) — papers, notes, and videos.")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.muted)
                }
                .padding(.horizontal, AppTheme.horizontalPadding)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(optionalSubjects) { subject in
                        NavigationLink(destination: ContentHubView(level: level, subject: subject, initialTab: initialTab)) {
                            SubjectCardView(subject: subject)
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
        .navigationTitle("Optionals")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct OptionalsListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            OptionalsListView(level: .form4)
        }
    }
}
