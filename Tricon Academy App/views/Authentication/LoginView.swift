import SwiftUI
import UIKit

struct LoginView: View {

    @EnvironmentObject private var authManager: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var rememberMe = true

    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isSocialLoading = false
    @State private var showComingSoon = false
    @State private var comingSoonMessage = ""

    private let brand = Color(red: 0.12, green: 0.62, blue: 0.36)
    private let brandDeep = Color(red: 0.08, green: 0.42, blue: 0.26)
    private let ink = Color(red: 0.09, green: 0.11, blue: 0.13)
    private let muted = Color(red: 0.45, green: 0.48, blue: 0.52)
    private let fieldFill = Color(red: 0.96, green: 0.965, blue: 0.972)

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isLoading && !isSocialLoading
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
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

                        Text("Welcome back")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(ink)

                        Text("Log in as a student, tutor, or admin to continue learning.")
                            .font(.system(size: 14))
                            .foregroundColor(muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 22)

                    // Social
                    VStack(spacing: 12) {
                        Button {
                            Task { await handleApple() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Continue with Apple")
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
                    .padding(.bottom, 20)

                    // Divider
                    HStack(spacing: 12) {
                        Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1)
                        Text("or log in with email")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(muted)
                            .fixedSize()
                        Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1)
                    }
                    .padding(.bottom, 18)

                    // Demo hint
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Demo accounts")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(muted)
                        Text("Admin · admin@tricon.com  ·  Tutor · tutor@tricon.com  ·  Student · any email")
                            .font(.system(size: 11))
                            .foregroundColor(muted.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(fieldFill)
                    )
                    .padding(.bottom, 14)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 0.75, green: 0.15, blue: 0.15))
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 10)
                    }

                    VStack(spacing: 12) {
                        iconField(icon: "envelope.fill", placeholder: "Email address", text: $email, keyboard: .emailAddress)
                        iconSecureField(icon: "lock.fill", placeholder: "Password", text: $password, isVisible: $showPassword)
                    }

                    HStack {
                        Button {
                            rememberMe.toggle()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                    .foregroundColor(rememberMe ? brand : muted)
                                Text("Remember me")
                                    .font(.system(size: 13))
                                    .foregroundColor(ink)
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            comingSoonMessage = "Password reset isn’t available yet. Use your existing account credentials for now."
                            showComingSoon = true
                        } label: {
                            Text("Forgot password?")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(brand)
                        }
                    }
                    .padding(.top, 12)

                    Button {
                        handleLogin()
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Log In")
                                    .fontWeight(.semibold)
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
                    .padding(.top, 18)

                    NavigationLink(destination: RegisterView()) {
                        HStack(spacing: 4) {
                            Text("Don’t have an account?")
                                .foregroundColor(muted)
                            Text("Sign Up")
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
        .navigationTitle("Log In")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isLoading || isSocialLoading)
        .alert("Coming soon", isPresented: $showComingSoon) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(comingSoonMessage)
        }
    }

    // MARK: - Actions

    private func handleLogin() {
        errorMessage = nil
        isLoading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let result = authManager.login(email: email, password: password, remember: rememberMe)
            isLoading = false

            switch result {
            case .success:
                break
            case .failure(let error):
                errorMessage = error.errorDescription
            }
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
            authManager.completeSocialSignIn(profile: profile)
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
            authManager.completeSocialSignIn(profile: profile)
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

    // MARK: - Fields

    @ViewBuilder
    private func iconField(icon: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(muted)
                .frame(width: 20)
            TextField(placeholder, text: text)
                .font(.system(size: 15))
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .textContentType(.emailAddress)
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

    @ViewBuilder
    private func iconSecureField(icon: String, placeholder: String, text: Binding<String>, isVisible: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(muted)
                .frame(width: 20)
            if isVisible.wrappedValue {
                TextField(placeholder, text: text)
                    .font(.system(size: 15))
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } else {
                SecureField(placeholder, text: text)
                    .font(.system(size: 15))
            }
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
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LoginView()
        }
        .environmentObject(AuthManager.shared)
    }
}
