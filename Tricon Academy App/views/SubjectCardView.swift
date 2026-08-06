import SwiftUI

/// Shared card UI used by both the main subject grid and the Optionals grid.
struct SubjectCardView: View {
    let subject: Subject

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(subject.swiftUIColor.opacity(0.14))
                    .frame(width: 48, height: 48)

                Image(systemName: subject.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(subject.swiftUIColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(subject.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text("Papers · Notes · Videos")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(AppTheme.muted)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.muted.opacity(0.7))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .stroke(subject.swiftUIColor.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}
