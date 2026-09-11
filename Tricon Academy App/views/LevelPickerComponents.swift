import SwiftUI

// MARK: - Shared form picker UI
// Simple, standard, professional tiles for Form 1–4.

enum LevelTileStyle {
    case grid
    case row
}

struct LevelTile: View {
    let level: Level
    var subtitle: String? = nil
    var accent: Color? = nil
    var style: LevelTileStyle = .grid

    private var color: Color { accent ?? level.accent }

    var body: some View {
        Group {
            switch style {
            case .grid: gridBody
            case .row: rowBody
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(level.rawValue)
        .accessibilityHint(resolvedSubtitle)
    }

    // MARK: Grid

    private var gridBody: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 52, height: 52)

                Text(level.shortLabel)
                    .appFont(size: 17, weight: .bold, design: .rounded)
                    .foregroundColor(color)
            }

            VStack(spacing: 3) {
                Text(level.rawValue)
                    .appFont(size: 15, weight: .semibold)
                    .foregroundColor(AppTheme.ink)
                    .lineLimit(1)

                Text(resolvedSubtitle)
                    .appFont(size: 12, weight: .medium)
                    .foregroundColor(AppTheme.muted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 128)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 3)
    }

    // MARK: Row

    private var rowBody: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                    .fill(color.opacity(0.14))
                    .frame(width: 48, height: 48)

                Text(level.shortLabel)
                    .appFont(size: 15, weight: .bold, design: .rounded)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(level.rawValue)
                    .appFont(size: 16, weight: .semibold)
                    .foregroundColor(AppTheme.ink)
                Text(resolvedSubtitle)
                    .appFont(size: 12.5, weight: .medium)
                    .foregroundColor(AppTheme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.subtle)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow, radius: 6, x: 0, y: 2)
    }

    private var resolvedSubtitle: String {
        subtitle ?? "\(allSubjects.count) subjects"
    }
}

// MARK: - Grid

struct LevelPickerGrid<Destination: View>: View {
    var subtitle: ((Level) -> String)? = nil
    var accent: ((Level) -> Color)? = nil
    @ViewBuilder var destination: (Level) -> Destination

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Level.activeCases) { level in
                NavigationLink(destination: destination(level)) {
                    LevelTile(
                        level: level,
                        subtitle: subtitle?(level),
                        accent: accent?(level),
                        style: .grid
                    )
                }
                .buttonStyle(LevelTilePressStyle())
            }
        }
    }
}

private struct LevelTilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Header

struct LevelPickerHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .appFont(size: 20, weight: .bold, design: .rounded)
                .foregroundColor(AppTheme.ink)
            Text(subtitle)
                .appFont(size: 13.5)
                .foregroundColor(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct LevelPickerComponents_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            LevelPickerGrid { _ in Text("dest") }
                .padding(22)
        }
        .background(AppTheme.canvas)
    }
}
