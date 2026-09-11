import SwiftUI

/// Shared card UI used by both the main subject grid and the Optionals grid.
struct SubjectCardView: View {
    let subject: Subject

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: subject.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.iconGreen)
                .symbolRenderingMode(.monochrome)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous)
                        .fill(AppTheme.iconWell)
                )
                .accessibilityHidden(true)

            Text(subject.name)
                .appFont(size: 15.5, weight: .bold)
                .foregroundColor(AppTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.88)

            Text("Papers · Notes · Videos")
                .appFont(size: 12, weight: .medium)
                .foregroundColor(AppTheme.secondaryInk)
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 158, alignment: .topLeading)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(AppTheme.cardLine, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subject.name). Papers, notes, and videos.")
        .accessibilityAddTraits(.isButton)
    }
}
