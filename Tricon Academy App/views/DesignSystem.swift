import SwiftUI
import UIKit

// MARK: - Global chrome (nav bar, tab bar, controls)

enum AppChrome {
    /// Call when the app launches or the user switches light/dark so system bars stay readable.
    static func apply(for scheme: ColorScheme) {
        let brand = UIColor(AppTheme.brandBright)

        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        nav.backgroundColor = .systemBackground
        nav.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        nav.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 32, weight: .bold)
        ]
        nav.shadowColor = .clear

        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = brand
        UINavigationBar.appearance().barTintColor = .systemBackground

        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        tab.backgroundColor = .secondarySystemBackground
        tab.shadowColor = UIColor.separator

        let item = UITabBarItemAppearance()
        item.normal.iconColor = .secondaryLabel
        item.normal.titleTextAttributes = [
            .foregroundColor: UIColor.secondaryLabel
        ]
        item.selected.iconColor = brand
        item.selected.titleTextAttributes = [
            .foregroundColor: brand,
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]
        tab.stackedLayoutAppearance = item
        tab.inlineLayoutAppearance = item
        tab.compactInlineLayoutAppearance = item

        UITabBar.appearance().standardAppearance = tab
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tab
        }
        UITabBar.appearance().tintColor = brand
        UITabBar.appearance().unselectedItemTintColor = .secondaryLabel
        UITabBar.appearance().barTintColor = .secondarySystemBackground

        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(AppTheme.brand)
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 13, weight: .semibold)],
            for: .selected
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor.label, .font: UIFont.systemFont(ofSize: 13, weight: .medium)],
            for: .normal
        )

        UITextField.appearance().tintColor = brand
        UITableView.appearance().backgroundColor = .systemBackground
        UIScrollView.appearance().indicatorStyle = scheme == .dark ? .white : .black
        _ = scheme
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
                .appFont(size: 18, weight: .bold)
                .foregroundColor(AppTheme.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .appFont(size: 14.5)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        if equalWidth && !dynamicTypeSize.isAccessibilitySize {
            ViewThatFits(in: .horizontal) {
                tabRow
                ScrollView(.horizontal, showsIndicators: false) { tabRow.fixedSize(horizontal: true, vertical: false) }
            }
        } else if equalWidth {
            ScrollView(.horizontal, showsIndicators: false) { tabRow }
        } else {
            tabRow
        }
    }

    private var tabRow: some View {
        HStack(spacing: 8) {
            ForEach(tabs) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selection = tab.id
                    }
                } label: {
                    pill(tab, selected: selection == tab.id)
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityAddTraits(selection == tab.id ? .isSelected : [])
            }
        }
    }

    private func pill(_ tab: ContentTypeTab, selected: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: tab.icon)
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.monochrome)
            Text(tab.title)
                .appFont(size: 13, weight: .semibold)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            if let count = tab.count, count > 0 {
                Text("\(count)")
                    .appFont(size: 11, weight: .bold, design: .rounded)
                    .foregroundColor(selected ? tab.color : AppTheme.secondaryInk)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(selected ? tab.soft : AppTheme.fill)
                    )
            }
        }
        .foregroundColor(selected ? tab.color : AppTheme.secondaryInk)
        .padding(.vertical, 12)
        .padding(.horizontal, equalWidth ? 6 : 12)
        .frame(maxWidth: equalWidth ? .infinity : nil)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(selected ? tab.soft : AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(selected ? tab.color.opacity(0.40) : AppTheme.cardLine, lineWidth: 1)
        )
        .accessibilityLabel(tab.count.map { "\(tab.title), \($0)" } ?? tab.title)
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
            .appFont(size: 11, weight: .bold)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}

// MARK: - Primary / secondary buttons

struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        let active = enabled && isEnabled
        return configuration.label
            .appFont(size: 16, weight: .semibold)
            .multilineTextAlignment(.center)
            .foregroundColor(active ? AppTheme.onBrand : AppTheme.muted)
            .tint(active ? AppTheme.onBrand : AppTheme.muted)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                    .fill(LinearGradient(
                        colors: active ? [AppTheme.brand, AppTheme.brandFillDeep] : [AppTheme.fill, AppTheme.fill],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
            }
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous))
            .shadow(color: active ? AppTheme.shadow : .clear, radius: 6, x: 0, y: 3)
            .scaleEffect(configuration.isPressed && active && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed && active ? 0.88 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(size: 15, weight: .semibold)
            .multilineTextAlignment(.center)
            .foregroundColor(isEnabled ? AppTheme.brandDeep : AppTheme.muted)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(isEnabled ? AppTheme.brandSoft : AppTheme.fill)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                    .strokeBorder(AppTheme.cardLine, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous))
            .opacity(configuration.isPressed && isEnabled ? 0.82 : 1)
    }
}

/// A consistent 44-point target for standalone bookmark, delete and utility icons.
struct AppIconLabel: View {
    let systemName: String
    var tint: Color = AppTheme.brandDeep
    var fill: Color = AppTheme.brandSoft

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundColor(tint)
            .frame(width: AppTheme.minimumTapTarget, height: AppTheme.minimumTapTarget)
            .background(RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous)
                .strokeBorder(tint.opacity(0.16), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous))
    }
}

// MARK: - Press feedback for tiles

struct SoftPressStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && isEnabled && !reduceMotion ? 0.98 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.86 : 1) : 0.5)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// Scale the shared typography with the reader's preferred text size.
private struct AppFontModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

extension View {
    func appFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(AppFontModifier(size: size, weight: weight, design: design))
    }
}

// MARK: - Authentication surfaces

/// Quiet texture and a soft wash of green behind the entry forms.
struct AuthBackdrop: View {
    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.canvas
            LinearGradient(
                colors: [AppTheme.brandSoft, AppTheme.canvas.opacity(0)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(height: 480)
            Canvas { context, size in
                var dots = Path()
                for x in stride(from: CGFloat(12), to: size.width, by: 24) {
                    for y in stride(from: CGFloat(12), to: size.height, by: 24) {
                        dots.addEllipse(in: CGRect(x: x, y: y, width: 1.5, height: 1.5))
                    }
                }
                context.fill(dots, with: .color(AppTheme.brand.opacity(0.10)))
            }
            .frame(height: 320)
            .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct AuthHeading: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 29, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 72, height: 72)
                .background(
                    LinearGradient(colors: [Color(red: 0.10, green: 0.44, blue: 0.34), AppTheme.brandFillDeep],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.24), lineWidth: 1))
                .shadow(color: AppTheme.brand.opacity(0.18), radius: 16, x: 0, y: 8)
                .accessibilityHidden(true)
            Text(title)
                .appFont(size: 30, weight: .bold, design: .rounded)
                .foregroundColor(AppTheme.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AuthFieldSurface: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .frame(minHeight: 60)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isFocused ? AppTheme.brand.opacity(0.65) : AppTheme.brand.opacity(0.12),
                              lineWidth: isFocused ? 1.5 : 1))
            .shadow(color: AppTheme.shadow.opacity(isFocused ? 0.65 : 0.3), radius: 8, x: 0, y: 3)
    }
}

struct AuthPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(size: 17, weight: .bold)
            .multilineTextAlignment(.center)
            .foregroundColor(isEnabled ? .white : AppTheme.secondaryInk)
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: isEnabled
                            ? [Color(red: 0.10, green: 0.43, blue: 0.33), AppTheme.brandFillDeep]
                            : [AppTheme.fill, AppTheme.fill],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(LinearGradient(
                        colors: [.white.opacity(isEnabled ? 0.35 : 0.08), .white.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    ), lineWidth: 1)
            }
            .shadow(color: isEnabled ? AppTheme.brand.opacity(0.22) : .clear,
                    radius: configuration.isPressed ? 3 : 12, x: 0, y: configuration.isPressed ? 2 : 6)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
