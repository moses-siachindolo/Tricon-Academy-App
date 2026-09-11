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
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Optional subjects")
                        .appFont(size: 18, weight: .bold)
                        .foregroundColor(AppTheme.ink)
                    Text("Optional subjects for \(level.rawValue) — papers, notes, and videos.")
                        .appFont(size: 13)
                        .foregroundColor(AppTheme.secondaryInk)
                }
                .padding(.horizontal, AppTheme.horizontalPadding)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(optionalSubjects) { subject in
                        NavigationLink(destination: ContentHubView(level: level, subject: subject, initialTab: initialTab)) {
                            SubjectCardView(subject: subject)
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(
            ZStack {
                AppTheme.canvas.ignoresSafeArea()
                LinearGradient(
                    colors: [AppTheme.brandSoft.opacity(0.38), AppTheme.canvas, AppTheme.canvas],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        )
        .navigationTitle("Optional Subjects")
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
