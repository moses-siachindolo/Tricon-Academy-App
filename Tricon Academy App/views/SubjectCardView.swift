import SwiftUI

/// Shared card UI used by both the main subject grid and the Optionals grid.
struct SubjectCardView: View {
    let subject: Subject

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(subject.swiftUIColor.opacity(0.16))
                        .frame(width: 48, height: 48)

                    Image(systemName: subject.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(subject.swiftUIColor)
                        .accessibilityHidden(true)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.subtle)
                    .padding(6)
                    .background(Circle().fill(AppTheme.fill))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(subject.name)
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundColor(AppTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)
                    .fixedSize(horizontal: false, vertical: true)

                // Explicit content types so students know what is inside
                HStack(spacing: 5) {
                    miniChip("Papers", AppTheme.papers)
                    miniChip("Notes", AppTheme.notes)
                    miniChip("Videos", AppTheme.videos)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .stroke(subject.swiftUIColor.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subject.name). Papers, notes, and videos.")
    }

    private func miniChip(_ title: String, _ color: Color) -> some View {
        Text(title)
            .font(.system(size: 9.5, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(color.opacity(0.14))
            )
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }
}
