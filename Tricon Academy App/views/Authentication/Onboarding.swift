import SwiftUI

// MARK: - Onboarding

/// Professional multi-page welcome flow for Tricon Academy.
/// Soft academic palette, feature-led pages, green brand CTAs.
struct OnboardingView: View {

    @State private var page = 0
    @State private var appear = false

    /// Entry green CTAs (pre-login — main app brand is blue after sign-in).
    private let brand = AppTheme.entryGreen
    private let brandDeep = AppTheme.entryGreenDeep
    private let ink = AppTheme.ink
    private let muted = AppTheme.muted
    private let canvas = AppTheme.canvas
    private let softDot = AppTheme.fill

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            badge: "TRICON ACADEMY",
            title: "Learn today,\nlead tomorrow",
            subtitle: "Your complete study companion for Form 1–4 — papers, notes, and video lessons in one place.",
            accent: Color(red: 0.12, green: 0.62, blue: 0.36),
            accentSoft: Color(red: 0.88, green: 0.96, blue: 0.91),
            illustration: .welcome
        ),
        OnboardingPage(
            badge: "PAST PAPERS",
            title: "Practice with\nreal exams",
            subtitle: "Browse past papers by subject and year. Build exam confidence with structured revision, not random scrolling.",
            accent: Color(red: 0.18, green: 0.42, blue: 0.78),
            accentSoft: Color(red: 0.90, green: 0.93, blue: 0.98),
            illustration: .papers
        ),
        OnboardingPage(
            badge: "LESSONS & NOTES",
            title: "Watch, read,\nand revise",
            subtitle: "Video lessons and study notes organised by topic so you can learn at your pace — before school or after.",
            accent: Color(red: 0.55, green: 0.28, blue: 0.78),
            accentSoft: Color(red: 0.95, green: 0.91, blue: 0.98),
            illustration: .lessons
        )
    ]

    private var isLastPage: Bool { page == pages.count - 1 }
    private var current: OnboardingPage { pages[page] }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                canvas.ignoresSafeArea()

                // Soft ambient wash behind the hero
                Circle()
                    .fill(current.accent.opacity(0.10))
                    .frame(width: geo.size.width * 0.95)
                    .blur(radius: 50)
                    .offset(y: -geo.size.height * 0.28)
                    .animation(.easeInOut(duration: 0.45), value: page)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 22)
                        .padding(.top, 8)

                    // Hero carousel
                    TabView(selection: $page) {
                        ForEach(pages.indices, id: \.self) { index in
                            OnboardingHeroCard(
                                page: pages[index],
                                brand: brand
                            )
                            .padding(.horizontal, 28)
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: min(geo.size.height * 0.42, 360))
                    .padding(.top, 8)

                    // Copy
                    VStack(spacing: 12) {
                        Text(current.badge)
                            .appFont(size: 12, weight: .semibold)
                            .tracking(1.4)
                            .foregroundColor(current.accent)
                            .padding(.top, 6)

                        Text(current.title)
                            .font(.system(size: titleSize(for: geo.size.width), weight: .bold))
                            .foregroundColor(ink)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(current.subtitle)
                            .appFont(size: 15.5, weight: .regular)
                            .foregroundColor(muted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: 340)
                    }
                    .padding(.horizontal, 28)
                    .animation(.easeInOut(duration: 0.28), value: page)
                    .id("copy-\(page)")

                    Spacer(minLength: 16)

                    // Dots
                    HStack(spacing: 7) {
                        ForEach(pages.indices, id: \.self) { index in
                            Capsule()
                                .fill(index == page ? brand : softDot)
                                .frame(width: index == page ? 22 : 8, height: 8)
                                .animation(.spring(response: 0.35, dampingFraction: 0.78), value: page)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Page \(page + 1) of \(pages.count)")
                    .padding(.bottom, 22)

                    // Actions
                    VStack(spacing: 12) {
                        if isLastPage {
                            NavigationLink(destination: RegisterView()) {
                                Text("Create Account")
                                    .appFont(size: 17, weight: .semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(
                                        LinearGradient(
                                            colors: [AppTheme.brand, AppTheme.brandFillDeep],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                                    .shadow(color: brand.opacity(0.28), radius: 14, x: 0, y: 8)
                            }
                            .buttonStyle(OnboardingPressStyle())

                            NavigationLink(destination: LoginView()) {
                                Text("I already have an account")
                                    .appFont(size: 15.5, weight: .semibold)
                                    .foregroundColor(ink)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                                            .fill(AppTheme.card)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                                            .stroke(AppTheme.strokeStrong, lineWidth: 1.2)
                                    )
                            }
                            .buttonStyle(OnboardingPressStyle())
                        } else {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    page += 1
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text("Continue")
                                    Image(systemName: "arrow.right")
                                        .appFont(size: 14, weight: .bold)
                                }
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [AppTheme.brand, AppTheme.brandFillDeep],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                                .shadow(color: brand.opacity(0.28), radius: 14, x: 0, y: 8)
                            }
                            .buttonStyle(OnboardingPressStyle())

                            NavigationLink(destination: LoginView()) {
                                Text("Log in")
                                    .appFont(size: 15.5, weight: .medium)
                                    .foregroundColor(muted)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, max(geo.safeAreaInsets.bottom, 16) + 10)
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 12)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) {
                appear = true
            }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.brand, AppTheme.brandFillDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 34, height: 34)
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }

                HStack(spacing: 0) {
                    Text("Tricon")
                        .appFont(size: 17, weight: .bold)
                        .foregroundColor(ink)
                    Text(" Academy")
                        .appFont(size: 17, weight: .medium)
                        .foregroundColor(muted)
                }
            }

            Spacer()

            if !isLastPage {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        page = pages.count - 1
                    }
                } label: {
                    Text("Skip")
                        .appFont(size: 15, weight: .medium)
                        .foregroundColor(muted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.04))
                        )
                }
                .accessibilityLabel("Skip onboarding")
            }
        }
    }

    private func titleSize(for width: CGFloat) -> CGFloat {
        width < 360 ? 28 : 32
    }
}

// MARK: - Page model

private struct OnboardingPage {
    enum Illustration {
        case welcome, papers, lessons, progress
    }

    let badge: String
    let title: String
    let subtitle: String
    let accent: Color
    let accentSoft: Color
    let illustration: Illustration
}

// MARK: - Hero card

private struct OnboardingHeroCard: View {
    let page: OnboardingPage
    let brand: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            page.accentSoft,
                            page.accentSoft.opacity(0.55),
                            AppTheme.card
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(page.accent.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: page.accent.opacity(0.12), radius: 24, x: 0, y: 12)

            // Decorative rings
            Circle()
                .stroke(page.accent.opacity(0.10), lineWidth: 1.5)
                .frame(width: 220, height: 220)
            Circle()
                .stroke(page.accent.opacity(0.07), lineWidth: 1)
                .frame(width: 280, height: 280)

            illustrationContent
                .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var illustrationContent: some View {
        switch page.illustration {
        case .welcome:
            WelcomeIllustration(accent: page.accent, brand: brand)
        case .papers:
            PapersIllustration(accent: page.accent)
        case .lessons:
            LessonsIllustration(accent: page.accent)
        case .progress:
            ProgressIllustration(accent: page.accent)
        }
    }
}

// MARK: - Illustrations

private struct WelcomeIllustration: View {
    let accent: Color
    let brand: Color

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: accent.opacity(0.35), radius: 16, x: 0, y: 8)

                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
            }

            HStack(spacing: 10) {
                miniChip(icon: "book.fill", label: "Form 1–4")
                miniChip(icon: "doc.text.fill", label: "Papers")
                miniChip(icon: "person.2.fill", label: "Tutors")
            }
        }
    }

    private func miniChip(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .appFont(size: 11, weight: .semibold)
        }
        .foregroundColor(accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(AppTheme.card.opacity(0.85))
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }
}

private struct PapersIllustration: View {
    let accent: Color

    var body: some View {
        ZStack {
            paperCard(offset: CGSize(width: -18, height: 14), rotation: -8, opacity: 0.55)
            paperCard(offset: CGSize(width: 16, height: 8), rotation: 7, opacity: 0.75)
            paperCard(offset: .zero, rotation: 0, opacity: 1.0, featured: true)
        }
    }

    private func paperCard(
        offset: CGSize,
        rotation: Double,
        opacity: Double,
        featured: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(accent.opacity(featured ? 0.9 : 0.5))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    )
                Spacer()
                Text("2024")
                    .appFont(size: 11, weight: .bold)
                    .foregroundColor(accent.opacity(0.8))
            }

            RoundedRectangle(cornerRadius: 3)
                .fill(Color.black.opacity(0.12))
                .frame(height: 8)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.black.opacity(0.08))
                .frame(width: featured ? 110 : 90, height: 8)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.black.opacity(0.06))
                .frame(width: featured ? 80 : 70, height: 8)

            if featured {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundColor(accent)
                    Text("Physics · Paper 1")
                        .appFont(size: 11, weight: .semibold)
                        .foregroundColor(Color(red: 0.2, green: 0.22, blue: 0.25))
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(width: 170, height: 150)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .fill(AppTheme.card)
                .shadow(color: accent.opacity(0.18), radius: featured ? 18 : 10, x: 0, y: featured ? 10 : 6)
        )
        .opacity(opacity)
        .rotationEffect(.degrees(rotation))
        .offset(offset)
    }
}

private struct LessonsIllustration: View {
    let accent: Color

    var body: some View {
        VStack(spacing: 14) {
            // Video card
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.9), accent.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 210, height: 120)
                    .shadow(color: accent.opacity(0.3), radius: 16, x: 0, y: 8)

                // Fake timeline bars
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.card.opacity(0.35))
                        .frame(height: 3)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                }
                .frame(width: 210, height: 120)

                Circle()
                    .fill(AppTheme.card)
                    .frame(width: 48, height: 48)
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(accent)
                            .offset(x: 1)
                    )
            }

            HStack(spacing: 10) {
                featurePill(icon: "note.text", title: "Notes")
                featurePill(icon: "play.rectangle.fill", title: "Videos")
                featurePill(icon: "bookmark.fill", title: "Saved")
            }
        }
    }

    private func featurePill(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .appFont(size: 12, weight: .semibold)
        }
        .foregroundColor(accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(AppTheme.card)
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        )
    }
}

private struct ProgressIllustration: View {
    let accent: Color

    private let weekDays = ["M", "T", "W", "T", "F", "S", "S"]
    private let weekHeights: [CGFloat] = [0.4, 0.65, 0.5, 0.9, 0.7, 0.35, 0.55]

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                statTile(value: "12", label: "Saved", icon: "bookmark.fill")
                statTile(value: "5", label: "Day streak", icon: "flame.fill")
            }

            // Weekly activity mock
            VStack(alignment: .leading, spacing: 10) {
                Text("This week")
                    .appFont(size: 12, weight: .semibold)
                    .foregroundColor(AppTheme.ink)

                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(weekDays.indices, id: \.self) { index in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [accent, accent.opacity(0.6)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 16, height: 54 * weekHeights[index])
                            Text(weekDays[index])
                                .appFont(size: 10, weight: .medium)
                                .foregroundColor(AppTheme.muted)
                        }
                    }
                
                }
                .frame(maxWidth: .infinity)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .fill(AppTheme.card)
                    .shadow(color: accent.opacity(0.14), radius: 12, x: 0, y: 6)
            )
            .frame(width: 230)
        }
    }

    private func statTile(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(accent)
            Text(value)
                .appFont(size: 22, weight: .bold)
                .foregroundColor(AppTheme.ink)
            Text(label)
                .appFont(size: 11, weight: .medium)
                .foregroundColor(AppTheme.muted)
        }
        .padding(14)
        .frame(width: 108, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .fill(AppTheme.card)
                .shadow(color: accent.opacity(0.14), radius: 12, x: 0, y: 6)
        )
    }
}

// MARK: - Button style

private struct OnboardingPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            OnboardingView()
        }
        .environmentObject(AuthManager.shared)
        .previewDevice("iPhone 15")
    }
}
