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
    @State private var isSocialLoading = false

    private let brand = Color(red: 0.12, green: 0.62, blue: 0.36)
    private let brandDeep = Color(red: 0.08, green: 0.42, blue: 0.26)
    private let ink = Color(red: 0.09, green: 0.11, blue: 0.13)
    private let muted = Color(red: 0.45, green: 0.48, blue: 0.52)
    private let fieldFill = Color(red: 0.96, green: 0.965, blue: 0.972)

    private var canSubmit: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && isValidEmail(email)
            && !phone.trimmingCharacters(in: .whitespaces).isEmpty
            && password.count >= 6
            && password == confirmPassword
            && agreeTerms
            && !isLoading
            && !isSocialLoading
    }

    private var passwordStrength: PasswordStrength {
        PasswordStrength.evaluate(password)
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                        .padding(.top, 8)
                        .padding(.bottom, 22)

                    socialSection
                        .padding(.bottom, 20)

                    divider
                        .padding(.bottom, 18)

                    formSection

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 0.75, green: 0.15, blue: 0.15))
                            .multilineTextAlignment(.center)
                            .padding(.top, 14)
                            .frame(maxWidth: .infinity)
                    }

                    termsRow
                        .padding(.top, 16)

                    primaryButton
                        .padding(.top, 18)

                    NavigationLink(destination: LoginView()) {
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .foregroundColor(muted)
                            Text("Log In")
                                .fontWeight(.semibold)
                                .foregroundColor(brand)
                        }
                        .font(.system(size: 14))
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
                .padding(.horizontal, 24)
                .frame(minHeight: geo.size.height, alignment: .top)
            }
            .background(Color(red: 0.985, green: 0.987, blue: 0.99).ignoresSafeArea())
        }
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isLoading || isSocialLoading)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [brand, brandDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: brand.opacity(0.3), radius: 14, x: 0, y: 8)

                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text("Join Tricon Academy")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(ink)

            Text("Create a free student or tutor account to access past papers, notes, and video lessons.")
                .font(.system(size: 14))
                .foregroundColor(muted)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Social

    private var socialSection: some View {
        VStack(spacing: 12) {
            // Sign in with Apple
            Button {
                Task { await handleApple() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 18, weight: .semibold))
                    Text(isSocialLoading ? "Please wait…" : "Continue with Apple")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(AuthPressStyle())
            .disabled(isSocialLoading || isLoading)

            // Continue with Google
            Button {
                Task { await handleGoogle() }
            } label: {
                HStack(spacing: 10) {
                    GoogleGlyph()
                        .frame(width: 18, height: 18)
                    Text("Continue with Google")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ink)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.10), lineWidth: 1.2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(AuthPressStyle())
            .disabled(isSocialLoading || isLoading)
        }
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1)
            Text("or sign up with email")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(muted)
                .fixedSize()
            Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1)
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 14) {
            // Role
            VStack(alignment: .leading, spacing: 8) {
                Text("I am a…")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ink)

                HStack(spacing: 10) {
                    ForEach(UserRole.registrableRoles) { role in
                        roleChip(role)
                    }
                }

                Text(selectedRole == .tutor
                     ? "Tutors can upload lessons and use the full learning app."
                     : "Students can browse, save, and study content.")
                    .font(.system(size: 12))
                    .foregroundColor(muted)
            }

            authField(icon: "person.fill", placeholder: "Full name", text: $fullName, contentType: .name)
            authField(icon: "envelope.fill", placeholder: "Email address", text: $email, keyboard: .emailAddress, contentType: .emailAddress)
            authField(icon: "phone.fill", placeholder: "Phone number", text: $phone, keyboard: .phonePad, contentType: .telephoneNumber)

            secureField(icon: "lock.fill", placeholder: "Password (min. 6 characters)", text: $password, isVisible: $showPassword)

            if !password.isEmpty {
                passwordStrengthBar
            }

            secureField(icon: "lock.fill", placeholder: "Confirm password", text: $confirmPassword, isVisible: $showConfirmPassword)
        }
    }

    private func roleChip(_ role: UserRole) -> some View {
        let selected = selectedRole == role
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedRole = role }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: role == .student ? "book.fill" : "checkmark.shield.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(role.displayName)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(selected ? .white : ink)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(roleChipBackground(selected: selected))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? Color.clear : Color.black.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func roleChipBackground(selected: Bool) -> some View {
        if selected {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [brand, brandDeep],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(fieldFill)
        }
    }

    private var passwordStrengthBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.06))
                    Capsule()
                        .fill(passwordStrength.color)
                        .frame(width: geo.size.width * passwordStrength.progress)
                        .animation(.easeInOut(duration: 0.2), value: passwordStrength)
                }
            }
            .frame(height: 5)

            Text(passwordStrength.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(passwordStrength.color)
        }
        .padding(.horizontal, 2)
    }

    private var termsRow: some View {
        Button {
            agreeTerms.toggle()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: agreeTerms ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundColor(agreeTerms ? brand : muted)

                Text("I agree to the Terms of Service and Privacy Policy for Tricon Academy.")
                    .font(.system(size: 13))
                    .foregroundColor(ink.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(agreeTerms ? "Terms agreed" : "Agree to terms")
    }

    private var primaryButton: some View {
        Button {
            Task { await handleRegister() }
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    HStack(spacing: 8) {
                        Text("Create Account")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
            }
            .font(.system(size: 16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: canSubmit ? [brand, brandDeep] : [brand.opacity(0.45), brandDeep.opacity(0.45)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: canSubmit ? brand.opacity(0.28) : .clear, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(AuthPressStyle())
        .disabled(!canSubmit)
    }

    // MARK: - Fields

    private func authField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(muted)
                .frame(width: 20)

            TextField(placeholder, text: text)
                .font(.system(size: 15))
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                .disableAutocorrection(true)
                .textContentType(contentType)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private func secureField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        isVisible: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(muted)
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
            .font(.system(size: 15))
            .textContentType(.newPassword)

            Button {
                isVisible.wrappedValue.toggle()
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                    .font(.system(size: 14))
                    .foregroundColor(muted)
            }
            .accessibilityLabel(isVisible.wrappedValue ? "Hide password" : "Show password")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Actions

    @MainActor
    private func handleRegister() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

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

        // Instant signup — account is created and the user is signed in right away.
        let result = authManager.register(
            fullName: fullName,
            email: email,
            phone: phone,
            password: password,
            preferredRole: selectedRole
        )

        switch result {
        case .success:
            // Root app observes isLoggedIn and shows MainTabView.
            break
        case .failure(let error):
            errorMessage = error.errorDescription
        }
    }

    @MainActor
    private func handleApple() async {
        errorMessage = nil
        isSocialLoading = true
        defer { isSocialLoading = false }

        guard let anchor = keyWindow() else {
            errorMessage = "Unable to present Sign in with Apple."
            return
        }

        do {
            let profile = try await SocialAuthService.shared.signInWithApple(anchor: anchor)
            authManager.completeSocialSignIn(profile: profile, preferredRole: selectedRole)
        } catch let error as SocialAuthError {
            if case .cancelled = error { return }
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func handleGoogle() async {
        errorMessage = nil
        isSocialLoading = true
        defer { isSocialLoading = false }

        guard EmailConfig.isGoogleConfigured else {
            errorMessage = SocialAuthError.googleNotConfigured.errorDescription
            return
        }

        guard let anchor = keyWindow() else {
            errorMessage = "Unable to present Google sign-in."
            return
        }

        do {
            let profile = try await SocialAuthService.shared.signInWithGoogle(anchor: anchor)
            authManager.completeSocialSignIn(profile: profile, preferredRole: selectedRole)
        } catch let error as SocialAuthError {
            if case .cancelled = error { return }
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let regex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: email.trimmingCharacters(in: .whitespaces))
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
        case .good: return Color(red: 0.25, green: 0.55, blue: 0.90)
        case .strong: return Color(red: 0.12, green: 0.62, blue: 0.36)
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
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct GoogleGlyph: View {
    var body: some View {
        // Lightweight multicolor G approximation using SF Symbol + tint layers.
        // For production branding you can replace with a Google "G" asset.
        ZStack {
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color(red: 0.26, green: 0.52, blue: 0.96),
                            Color(red: 0.22, green: 0.73, blue: 0.40),
                            Color(red: 0.98, green: 0.74, blue: 0.02),
                            Color(red: 0.92, green: 0.26, blue: 0.21),
                            Color(red: 0.26, green: 0.52, blue: 0.96)
                        ],
                        center: .center
                    ),
                    lineWidth: 2.2
                )
            Text("G")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(red: 0.26, green: 0.52, blue: 0.96))
        }
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
