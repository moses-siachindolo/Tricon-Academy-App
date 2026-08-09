import SwiftUI
import UIKit

// MARK: - Global chrome (nav bar, tab bar, controls)

enum AppChrome {
    /// Call when the app launches or the user switches light/dark so system bars stay readable.
    static func apply(for scheme: ColorScheme) {
        let isDark = scheme == .dark

        let canvas = isDark
            ? UIColor(red: 0.04, green: 0.045, blue: 0.05, alpha: 1)
            : UIColor(red: 0.955, green: 0.962, blue: 0.968, alpha: 1)
        let card = isDark
            ? UIColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1)
            : UIColor.white
        let ink = isDark
            ? UIColor(red: 0.98, green: 0.985, blue: 0.99, alpha: 1)
            : UIColor(red: 0.04, green: 0.06, blue: 0.07, alpha: 1)
        let brand = UIColor(red: 0.07, green: 0.58, blue: 0.36, alpha: 1)

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = canvas
        nav.titleTextAttributes = [
            .foregroundColor: ink,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        nav.largeTitleTextAttributes = [
            .foregroundColor: ink,
            .font: UIFont.systemFont(ofSize: 32, weight: .bold)
        ]
        nav.shadowColor = .clear

        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = brand

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = card
        tab.shadowColor = isDark
            ? UIColor.white.withAlphaComponent(0.10)
            : UIColor.black.withAlphaComponent(0.08)

        let item = UITabBarItemAppearance()
        let normal = isDark
            ? UIColor(red: 0.62, green: 0.65, blue: 0.64, alpha: 1)
            : UIColor(red: 0.38, green: 0.42, blue: 0.44, alpha: 1)
        item.normal.iconColor = normal
        item.normal.titleTextAttributes = [.foregroundColor: normal]
        item.selected.iconColor = brand
        item.selected.titleTextAttributes = [.foregroundColor: brand]
        tab.stackedLayoutAppearance = item
        tab.inlineLayoutAppearance = item
        tab.compactInlineLayoutAppearance = item

        UITabBar.appearance().standardAppearance = tab
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tab
        }
        UITabBar.appearance().tintColor = brand
        UITabBar.appearance().unselectedItemTintColor = normal

        UISegmentedControl.appearance().selectedSegmentTintColor = brand
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 13, weight: .semibold)],
            for: .selected
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: ink, .font: UIFont.systemFont(ofSize: 13, weight: .medium)],
            for: .normal
        )

        UITextField.appearance().tintColor = brand
    }
}

// MARK: - Card chrome

struct AppCardModifier: ViewModifier {
    var radius: CGFloat = AppTheme.cardRadius
    var padding: CGFloat? = nil
    var elevated: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(padding ?? 0)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(AppTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppTheme.stroke, lineWidth: 1)
            )
            .shadow(color: elevated ? AppTheme.shadow : .clear, radius: elevated ? 10 : 0, x: 0, y: elevated ? 4 : 0)
    }
}

extension View {
    func appCard(radius: CGFloat = AppTheme.cardRadius, elevated: Bool = true) -> some View {
        modifier(AppCardModifier(radius: radius, elevated: elevated))
    }

    /// Screen root: full-bleed canvas + ink-friendly environment.
    func appScreen() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.canvas.ignoresSafeArea())
    }
}

// MARK: - Empty state

struct AppEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var accent: Color = AppTheme.brandBright
    var soft: Color = AppTheme.brandSoft

    var body: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 28)
            ZStack {
                Circle()
                    .fill(soft)
                    .frame(width: 84, height: 84)
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(accent)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.system(size: 14.5))
                .foregroundColor(AppTheme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 24)
                .fixedSize(horizontal: false, vertical: true)
            Spacer().frame(height: 28)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Content type selector (Papers / Notes / Videos)

/// Icon + label tabs used on subject hubs and saved filters.
struct ContentTypeSelector: View {
    @Binding var selection: Int
    var tabs: [ContentTypeTab]
    /// When true (default), tabs share width evenly. Use false for horizontal scroll chips.
    var equalWidth: Bool = true

    struct ContentTypeTab: Identifiable {
        let id: Int
        let title: String
        let icon: String
        let color: Color
        let soft: Color
        var count: Int? = nil
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(tabs) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selection = tab.id
                    }
                } label: {
                    pill(tab, selected: selection == tab.id)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab.id ? .isSelected : [])
            }
        }
    }

    private func pill(_ tab: ContentTypeTab, selected: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: tab.icon)
                .font(.system(size: 13, weight: .semibold))
            Text(tab.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            if let count = tab.count, count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(selected ? tab.color : AppTheme.subtle)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(selected ? tab.soft.opacity(0.9) : AppTheme.fill)
                    )
            }
        }
        .foregroundColor(selected ? tab.color : AppTheme.muted)
        .padding(.vertical, 11)
        .padding(.horizontal, equalWidth ? 6 : 12)
        .frame(maxWidth: equalWidth ? .infinity : nil)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selected ? tab.soft : AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selected ? tab.color.opacity(0.35) : AppTheme.stroke, lineWidth: selected ? 1.5 : 1)
        )
    }

    /// Standard Papers / Notes / Videos trio for subject hubs.
    static func subjectTabs(
        papers: Int = 0,
        notes: Int = 0,
        videos: Int = 0,
        showCounts: Bool = true
    ) -> [ContentTypeTab] {
        [
            ContentTypeTab(
                id: 0,
                title: "Papers",
                icon: "doc.text.fill",
                color: AppTheme.papers,
                soft: AppTheme.papersSoft,
                count: showCounts ? papers : nil
            ),
            ContentTypeTab(
                id: 1,
                title: "Notes",
                icon: "note.text",
                color: AppTheme.notes,
                soft: AppTheme.notesSoft,
                count: showCounts ? notes : nil
            ),
            ContentTypeTab(
                id: 2,
                title: "Videos",
                icon: "play.rectangle.fill",
                color: AppTheme.videos,
                soft: AppTheme.videosSoft,
                count: showCounts ? videos : nil
            )
        ]
    }
}

// MARK: - Section micro labels

struct SectionChip: View {
    let title: String
    var color: Color = AppTheme.brandBright

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}

// MARK: - Primary / secondary buttons

struct AppPrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(AppTheme.onBrand)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: enabled
                        ? [AppTheme.brand, AppTheme.brand.opacity(0.85)]
                        : [AppTheme.brand.opacity(0.40), AppTheme.brand.opacity(0.35)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous))
            .shadow(color: enabled ? AppTheme.brand.opacity(0.28) : .clear, radius: 12, x: 0, y: 6)
            .scaleEffect(configuration.isPressed && enabled ? 0.98 : 1)
            .opacity(configuration.isPressed && enabled ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(AppTheme.brandDeep)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(AppTheme.brandSoft)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                    .stroke(AppTheme.brand.opacity(0.22), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

// MARK: - Press feedback for tiles

struct SoftPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
