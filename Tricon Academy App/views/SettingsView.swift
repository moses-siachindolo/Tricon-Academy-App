import SwiftUI

/// User preferences: app appearance (white / black).
struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {

                // MARK: Appearance
                VStack(alignment: .leading, spacing: 12) {
                    Text("Appearance")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.muted)
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("App theme")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.ink)

                        Text("Choose a white or black look for the whole app.")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.muted)

                        HStack(spacing: 12) {
                            themeCard(
                                title: "White",
                                subtitle: "Light",
                                icon: "sun.max.fill",
                                isSelected: !settings.useDarkTheme,
                                previewCanvas: Color(red: 0.96, green: 0.97, blue: 0.97),
                                previewCard: .white,
                                previewInk: Color(red: 0.1, green: 0.12, blue: 0.11)
                            ) {
                                settings.useDarkTheme = false
                            }

                            themeCard(
                                title: "Black",
                                subtitle: "Dark",
                                icon: "moon.fill",
                                isSelected: settings.useDarkTheme,
                                previewCanvas: Color(red: 0.08, green: 0.08, blue: 0.09),
                                previewCard: Color(red: 0.16, green: 0.16, blue: 0.18),
                                previewInk: Color.white.opacity(0.9)
                            ) {
                                settings.useDarkTheme = true
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.stroke, lineWidth: 1)
                    )
                }
                .padding(.horizontal, AppTheme.horizontalPadding)

                // MARK: About
                VStack(alignment: .leading, spacing: 12) {
                    Text("About")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.muted)
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        settingsInfoRow(title: "App", value: "Tricon Academy")
                        Divider().padding(.leading, 16)
                        settingsInfoRow(title: "Version", value: "1.0")
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.stroke, lineWidth: 1)
                    )
                }
                .padding(.horizontal, AppTheme.horizontalPadding)

                Spacer(minLength: 32)
            }
            .padding(.top, 16)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func themeCard(
        title: String,
        subtitle: String,
        icon: String,
        isSelected: Bool,
        previewCanvas: Color,
        previewCard: Color,
        previewInk: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(previewCanvas)
                        .frame(height: 72)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(previewCard)
                                .frame(width: 48, height: 28)
                                .padding(12),
                            alignment: .topLeading
                        )
                        .overlay(
                            Circle()
                                .fill(previewInk.opacity(0.35))
                                .frame(width: 14, height: 14)
                                .padding(12),
                            alignment: .bottomTrailing
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? AppTheme.brand : AppTheme.stroke, lineWidth: isSelected ? 2 : 1)
                        )

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AppTheme.brand)
                            .padding(8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? AppTheme.brandDeep : AppTheme.muted)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.ink)
                        Text(subtitle)
                            .font(.system(size: 11.5))
                            .foregroundColor(AppTheme.muted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func settingsInfoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(AppTheme.ink)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
        }
    }
}
