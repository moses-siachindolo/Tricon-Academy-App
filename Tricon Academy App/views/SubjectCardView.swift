import SwiftUI

/// Shared card UI used by both the main subject grid and the Optionals grid.
struct SubjectCardView: View {
    let subject: Subject

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                Circle()
                    .fill(subject.swiftUIColor.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: subject.icon)
                    .font(.system(size: 22))
                    .foregroundColor(subject.swiftUIColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(subject.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text("Papers · Notes · Videos")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(18)
    }
}
