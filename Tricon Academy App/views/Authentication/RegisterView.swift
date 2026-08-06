import SwiftUI
import UIKit

struct RegisterView: View {

    @EnvironmentObject private var authManager: AuthManager

    @State private var fullName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedRole: UserRole = .student

    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var agreeTerms = false

    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var appeared = false

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case fullName, email, phone, password, confirmPassword
    }

    // MARK: - Professional palette
    // Deep emerald + cool teal + soft champagne highlight for a premium, unique feel

    private let brand = Color(red: 0.09, green: 0.62, blue: 0.45)
    private let brandMid = Color(red: 0.07, green: 0.52, blue: 0.48)
    private let brandDeep = Color(red: 0.05, green: 0.32, blue: 0.34)
    private let brandGlow = Color(red: 0.18, green: 0.78, blue: 0.58)
    private let brandSoft = Color(red: 0.90, green: 0.96, blue: 0.94)
    private let champagne = Color(red: 0.94, green: 0.90, blue: 0.78)
    private let canvasTop = Color(red: 0.955, green: 0.972, blue: 0.968)
    private let canvasBottom = Color(red: 0.935, green: 0.955, blue: 0.960)
    private let ink = Color(red: 0.07, green: 0.11, blue: 0.12)
    private let muted = Color(red: 0.40, green: 0.46, blue: 0.45)
    private let fieldFill = Color.white
    private let cardFill = Color.white
    private let danger = Color(red: 0.82, green: 0.22, blue: 0.22)

    private var canSubmit: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && isValidEmail(email)
            && !phone.trimmingCharacters(in: .whitespaces).isEmpty
            && password.count >= 6
            && password == confirmPassword
            && agreeTerms
            && !isLoading
    }

    private var passwordStrength: PasswordStrength {
        PasswordStrength.evaluate(password)
    }

    private var emailIsInvalid: Bool {
        !email.isEmpty && !isValidEmail(email)
    }

    private var passwordsMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
    }

    /// Signature multi-stop brand gradient used across CTAs
    private var brandGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: brandGlow, location: 0),
                .init(color: brand, location: 0.42),
                .init(color: brandMid, location: 0.72),
                .init(color: brandDeep, location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var brandGradientMuted: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: brand.opacity(0.42), location: 0),
                .init(color: brandDeep.opacity(0.38), location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Layered canvas gradient
                LinearGradient(
                    colors: [canvasTop, canvasBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ambientBackground(in: geo.size)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        header
                            .padding(.top, 6)
                            .padding(.bottom, 24)

                        formCard
                            .padding(.bottom, 18)

                        actionFooter
                            .padding(.bottom, 36)
                    }
                    .padding(.horizontal, 20)
                    .frame(minHeight: geo.size.height, alignment: .top)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 18)
                }
            }
        }
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isLoading)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }

    // MARK: - Ambient background

    private func ambientBackground(in size: CGSize) -> some View {
        ZStack {
            // Soft diagonal wash
            LinearGradient(
                stops: [
                    .init(color: brand.opacity(0.10), location: 0),
                    .init(color: Color.clear, location: 0.45),
                    .init(color: brandDeep.opacity(0.06), location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Top-left emerald orb
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [brandGlow.opacity(0.28), brand.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: size.width * 0.55
                    )
                )
                .frame(width: size.width * 1.05, height: size.width * 0.85)
                .offset(x: -size.width * 0.32, y: -size.height * 0.28)
                .blur(radius: 8)
                .allowsHitTesting(false)

            // Bottom-right deep teal orb
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [brandDeep.opacity(0.16), brandMid.opacity(0.05), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: size.width * 0.5
                    )
                )
                .frame(width: size.width * 0.95, height: size.width * 0.8)
                .offset(x: size.width * 0.38, y: size.height * 0.42)
                .blur(radius: 12)
                .allowsHitTesting(false)

            // Subtle champagne highlight (premium accent)
            Circle()
                .fill(champagne.opacity(0.18))
                .frame(width: size.width * 0.4)
                .blur(radius: 40)
                .offset(x: size.width * 0.28, y: -size.height * 0.08)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                // Outer soft halo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [brandSoft, brandSoft.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 52
                        )
                    )
                    .frame(width: 104, height: 104)

                // Thin ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [brand.opacity(0.35), brandDeep.opacity(0.12), champagne.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 84, height: 84)

                // Brand badge
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(brandGradient)
                    .frame(width: 60, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.45), Color.white.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: brand.opacity(0.35), radius: 16, x: 0, y: 10)
                    .shadow(color: brandDeep.opacity(0.18), radius: 4, x: 0, y: 2)

                Image(systemName: "person.badge.plus")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 8) {
                Text("Join Tricon Academy")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(ink)
                    .tracking(-0.3)

                Text("Free access to past papers, notes, and video lessons — for students and tutors.")
                    .font(.system(size: 14.5, weight: .regular))
                    .foregroundColor(muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 10)
            }

            // Trust chips — refined pills
            HStack(spacing: 8) {
                trustChip(icon: "checkmark.seal.fill", label: "Free forever")
                trustChip(icon: "lock.shield.fill", label: "Secure")
                trustChip(icon: "bolt.fill", label: "Instant access")
            }
            .padding(.top, 2)
        }
    }

    private func trustChip(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(label)
                .font(.system(size: 11.5, weight: .semibold))
        }
        .foregroundColor(brandDeep)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.95), brandSoft.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [brand.opacity(0.22), brandDeep.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: brand.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    // MARK: - Form card

    private var formCard: some View {
        VStack(spacing: 22) {
            rolePicker

            // Divider with label
            sectionDivider(title: "Your details")

            VStack(spacing: 14) {
                labeledField(label: "Full name", icon: "person.fill", placeholder: "Your full name", text: $fullName, field: .fullName, contentType: .name)

                VStack(alignment: .leading, spacing: 6) {
                    labeledField(label: "Email", icon: "envelope.fill", placeholder: "name@example.com", text: $email, field: .email, keyboard: .emailAddress, contentType: .emailAddress, autocap: .never)

                    if emailIsInvalid {
                        fieldError("Enter a valid email address.")
                    }
                }

                labeledField(label: "Phone", icon: "phone.fill", placeholder: "Phone number", text: $phone, field: .phone, keyboard: .phonePad, contentType: .telephoneNumber)
            }

            sectionDivider(title: "Security")

            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    labeledSecureField(label: "Password", icon: "lock.fill", placeholder: "Min. 6 characters", text: $password, field: .password, isVisible: $showPassword)

                    if !password.isEmpty {
                        passwordStrengthBar
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    labeledSecureField(label: "Confirm password", icon: "lock.fill", placeholder: "Re-enter password", text: $confirmPassword, field: .confirmPassword, isVisible: $showConfirmPassword)

                    if passwordsMismatch {
                        fieldError("Passwords do not match.")
                    }
                }
            }

            if let errorMessage {
                errorBanner(errorMessage)
            }

            termsRow

            // CTA stack
            VStack(spacing: 12) {
                primaryButton
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white, brandSoft.opacity(0.25)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .opacity(0.5)
                        .allowsHitTesting(false)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.95),
                            brand.opacity(0.14),
                            brandDeep.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: brandDeep.opacity(0.07), radius: 32, x: 0, y: 16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func sectionDivider(title: String) -> some View {
        HStack(spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(muted.opacity(0.85))
                .tracking(0.8)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [brand.opacity(0.18), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
        .padding(.top, 2)
    }

    // MARK: - Role picker (card layout)

    private var rolePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("I am a…")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ink)
                .padding(.leading, 2)

            HStack(spacing: 12) {
                ForEach(UserRole.registrableRoles) { role in
                    roleCard(role)
                }
            }

            Text(selectedRole == .tutor
                 ? "Tutors can upload lessons and use the full learning app."
                 : "Students can browse, save, and study content.")
                .font(.system(size: 12.5))
                .foregroundColor(muted)
                .padding(.leading, 2)
                .animation(.easeOut(duration: 0.2), value: selectedRole)
        }
    }

    private func roleCard(_ role: UserRole) -> some View {
        let selected = selectedRole == role
        let icon = role == .student ? "book.fill" : "checkmark.shield.fill"
        let subtitle = role == .student ? "Learn & revise" : "Teach & share"

        return Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                selectedRole = role
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? Color.white.opacity(0.22) : brandSoft)
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(selected ? .white : brandDeep)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(role.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(selected ? .white : ink)

                    Text(subtitle)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(selected ? Color.white.opacity(0.82) : muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(brandGradient)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.4), Color.white.opacity(0.05)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: brand.opacity(0.32), radius: 14, x: 0, y: 6)
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.965, green: 0.975, blue: 0.972))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(brand.opacity(0.10), lineWidth: 1)
                        )
                }
            }
        }
        .buttonStyle(AuthPressStyle())
        .accessibilityLabel("\(role.displayName), \(selected ? "selected" : "not selected")")
    }

    // MARK: - Terms

    private var termsRow: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                agreeTerms.toggle()
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            agreeTerms
                                ? brandGradient
                                : LinearGradient(
                                    colors: [Color(red: 0.95, green: 0.96, blue: 0.96), Color(red: 0.93, green: 0.94, blue: 0.94)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 24, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(
                                    agreeTerms
                                        ? Color.white.opacity(0.3)
                                        : Color.black.opacity(0.10),
                                    lineWidth: 1.2
                                )
                        )
                        .shadow(color: agreeTerms ? brand.opacity(0.28) : .clear, radius: 6, x: 0, y: 3)

                    if agreeTerms {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Text("I agree to the Terms of Service and Privacy Policy for Tricon Academy.")
                    .font(.system(size: 13))
                    .foregroundColor(ink.opacity(0.78))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(agreeTerms ? brandSoft.opacity(0.55) : Color(red: 0.97, green: 0.975, blue: 0.975))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(agreeTerms ? brand.opacity(0.2) : Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(agreeTerms ? "Terms agreed" : "Agree to terms")
    }

    // MARK: - Primary button

    private var primaryButton: some View {
        Button {
            Task { await handleRegister() }
        } label: {
            ZStack {
                // Soft glow plate when active
                if canSubmit {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [brandGlow.opacity(0.45), brand.opacity(0.25)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .blur(radius: 14)
                        .offset(y: 8)
                        .frame(height: 54)
                }

                HStack(spacing: 0) {
                    Spacer(minLength: 0)

                    Group {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            HStack(spacing: 10) {
                                Text("Create Account")
                                    .font(.system(size: 17, weight: .semibold))

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .padding(6)
                                    .background(
                                        Circle()
                                            .fill(Color.white.opacity(canSubmit ? 0.22 : 0.12))
                                    )
                            }
                        }
                    }
                    .foregroundColor(.white)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Group {
                        if canSubmit {
                            brandGradient
                        } else {
                            brandGradientMuted
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    // Top edge light for depth
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(canSubmit ? 0.38 : 0.12),
                                    Color.white.opacity(0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: canSubmit ? brand.opacity(0.34) : .clear, radius: 18, x: 0, y: 10)
                .shadow(color: canSubmit ? brandDeep.opacity(0.18) : .clear, radius: 4, x: 0, y: 2)
            }
        }
        .buttonStyle(AuthPressStyle())
        .disabled(!canSubmit)
        .animation(.easeOut(duration: 0.22), value: canSubmit)
    }

    // MARK: - Footer (secondary button layout)

    private var actionFooter: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.black.opacity(0.06))
                    .frame(height: 1)
                Text("or")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(muted)
                Rectangle()
                    .fill(Color.black.opacity(0.06))
                    .frame(height: 1)
            }
            .padding(.horizontal, 8)

            NavigationLink(destination: LoginView()) {
                HStack(spacing: 8) {
                    Text("Already have an account?")
                        .font(.system(size: 14))
                        .foregroundColor(muted)
                    Text("Log In")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(brandDeep)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(brand)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [brand.opacity(0.22), brandDeep.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(AuthPressStyle())
        }
    }

    // MARK: - Field helpers

    private func fieldError(_ message: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 11))
            Text(message)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(danger)
        .padding(.horizontal, 4)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(danger)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(danger)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(danger.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(danger.opacity(0.18), lineWidth: 1)
        )
    }

    private var passwordStrengthBar: some View {
        VStack(alignment: .leading, spacing: 7) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.06))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [passwordStrength.color, passwordStrength.color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * passwordStrength.progress))
                        .animation(.easeInOut(duration: 0.22), value: passwordStrength)
                }
            }
            .frame(height: 5)

            HStack(spacing: 6) {
                Circle()
                    .fill(passwordStrength.color)
                    .frame(width: 6, height: 6)
                Text(passwordStrength.label)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(passwordStrength.color)
            }
        }
        .padding(.horizontal, 2)
    }

    private func labeledField(
        label: String,
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        autocap: TextInputAutocapitalization = .words
    ) -> some View {
        let isFocused = focusedField == field
        return VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(isFocused ? brandDeep : muted)
                .padding(.leading, 2)
                .animation(.easeOut(duration: 0.15), value: isFocused)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isFocused ? brand : muted.opacity(0.85))
                    .frame(width: 20)

                TextField(placeholder, text: text)
                    .font(.system(size: 15.5))
                    .foregroundColor(ink)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(autocap)
                    .disableAutocorrection(true)
                    .textContentType(contentType)
                    .focused($focusedField, equals: field)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isFocused ? brandSoft.opacity(0.5) : fieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isFocused
                            ? LinearGradient(
                                colors: [brand, brandMid],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                            : LinearGradient(
                                colors: [Color.black.opacity(0.07), Color.black.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                              ),
                        lineWidth: isFocused ? 1.6 : 1
                    )
            )
            .shadow(color: isFocused ? brand.opacity(0.14) : Color.black.opacity(0.02), radius: isFocused ? 12 : 2, x: 0, y: isFocused ? 5 : 1)
            .animation(.easeOut(duration: 0.18), value: isFocused)
        }
    }

    private func labeledSecureField(
        label: String,
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        isVisible: Binding<Bool>
    ) -> some View {
        let isFocused = focusedField == field
        return VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(isFocused ? brandDeep : muted)
                .padding(.leading, 2)
                .animation(.easeOut(duration: 0.15), value: isFocused)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isFocused ? brand : muted.opacity(0.85))
                    .frame(width: 20)

                Group {
                    if isVisible.wrappedValue {
                        TextField(placeholder, text: text)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    } else {
                        SecureField(placeholder, text: text)
                    }
                }
                .font(.system(size: 15.5))
                .foregroundColor(ink)
                .textContentType(.newPassword)
                .focused($focusedField, equals: field)

                Button {
                    isVisible.wrappedValue.toggle()
                } label: {
                    Image(systemName: isVisible.wrappedValue ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 13))
                        .foregroundColor(muted)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.04))
                        )
                }
                .accessibilityLabel(isVisible.wrappedValue ? "Hide password" : "Show password")
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isFocused ? brandSoft.opacity(0.5) : fieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isFocused
                            ? LinearGradient(
                                colors: [brand, brandMid],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                            : LinearGradient(
                                colors: [Color.black.opacity(0.07), Color.black.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                              ),
                        lineWidth: isFocused ? 1.6 : 1
                    )
            )
            .shadow(color: isFocused ? brand.opacity(0.14) : Color.black.opacity(0.02), radius: isFocused ? 12 : 2, x: 0, y: isFocused ? 5 : 1)
            .animation(.easeOut(duration: 0.18), value: isFocused)
        }
    }

    // MARK: - Actions

    @MainActor
    private func handleRegister() async {
        errorMessage = nil

        guard !fullName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your full name."
            return
        }
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address."
            return
        }
        guard !phone.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your phone number."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        guard agreeTerms else {
            errorMessage = "Please agree to the Terms of Service to continue."
            return
        }

        isLoading = true
        defer { isLoading = false }

        let result = await authManager.register(
            fullName: fullName,
            email: email,
            phone: phone,
            password: password,
            preferredRole: selectedRole
        )

        switch result {
        case .success:
            break
        case .failure(let error):
            errorMessage = error.errorDescription
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.contains(" ") else { return false }
        let regex = "^[A-Za-z0-9]+([._%+-][A-Za-z0-9]+)*@[A-Za-z0-9]+([.-][A-Za-z0-9]+)*\\.[A-Za-z]{2,}$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmed)
    }
}

// MARK: - Password strength

private enum PasswordStrength: Equatable {
    case weak, fair, good, strong

    var progress: CGFloat {
        switch self {
        case .weak: return 0.25
        case .fair: return 0.5
        case .good: return 0.75
        case .strong: return 1.0
        }
    }

    var label: String {
        switch self {
        case .weak: return "Weak password"
        case .fair: return "Fair password"
        case .good: return "Good password"
        case .strong: return "Strong password"
        }
    }

    var color: Color {
        switch self {
        case .weak: return Color(red: 0.85, green: 0.25, blue: 0.22)
        case .fair: return Color(red: 0.92, green: 0.62, blue: 0.12)
        case .good: return Color(red: 0.22, green: 0.52, blue: 0.88)
        case .strong: return Color(red: 0.09, green: 0.62, blue: 0.45)
        }
    }

    static func evaluate(_ password: String) -> PasswordStrength {
        var score = 0
        if password.count >= 6 { score += 1 }
        if password.count >= 10 { score += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { score += 1 }

        switch score {
        case 0...1: return .weak
        case 2: return .fair
        case 3: return .good
        default: return .strong
        }
    }
}

// MARK: - Shared UI bits

struct AuthPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RegisterView()
        }
        .environmentObject(AuthManager.shared)
    }
}
